defmodule Wik.Events.ExternalCalendar.Sync do
  @moduledoc false

  import Ecto.Query, only: [from: 2]

  require Logger

  alias Utils.Values
  alias Wik.Events.ExternalCalendar.Fetch
  alias Wik.Events.ExternalCalendarSubscription
  alias Wik.Events.ExternalEvent
  alias Wik.Repo

  @default_tz "Etc/UTC"
  @future_horizon_months 2
  @recent_past_days 7

  def sync_subscription(%ExternalCalendarSubscription{} = subscription, opts \\ []) do
    http_get = Keyword.get(opts, :http_get, Fetch.http_get())

    with {:ok, response} <-
           http_get.(subscription.ics_url, Fetch.refresh_request_options(subscription)) do
      handle_refresh_response(subscription, response)
    else
      {:error, error} ->
        handle_refresh_error(subscription, "Fetch failed: #{Exception.message(error)}")

      _ ->
        handle_refresh_error(subscription, "Calendar feed response was invalid")
    end
  end

  def sync_subscription_by_id(subscription_id, opts \\ []) do
    case Repo.get(ExternalCalendarSubscription, subscription_id) do
      nil -> {:error, :not_found}
      subscription -> sync_subscription(subscription, opts)
    end
  end

  def sync_all_subscriptions(opts \\ []) do
    Repo.all(ExternalCalendarSubscription)
    |> Task.async_stream(&sync_subscription_safely(&1, opts),
      max_concurrency: 1,
      timeout: :infinity
    )
    |> Stream.run()

    :ok
  end

  def materialization_horizon_end(now \\ DateTime.utc_now()) do
    now
    |> DateTime.to_date()
    |> Date.shift(month: @future_horizon_months)
    |> DateTime.new!(~T[23:59:59], @default_tz)
    |> with_utc_usec()
  end

  def recent_past_start(now \\ DateTime.utc_now()) do
    now
    |> DateTime.to_date()
    |> Date.add(-@recent_past_days)
    |> DateTime.new!(~T[00:00:00], @default_tz)
    |> with_utc_usec()
  end

  def materialized_events(subscription, calendar, calendar_name, raw_event_metadata) do
    calendar.events
    |> Enum.group_by(&(&1.uid || fallback_uid(&1)))
    |> Enum.flat_map(fn {_uid, events} ->
      materialized_events_for_uid(subscription, events, calendar_name, raw_event_metadata)
    end)
    |> Enum.sort_by(&{DateTime.to_unix(&1.starts_at, :microsecond), &1.id})
  end

  defp handle_refresh_response(subscription, %Req.Response{status: 304}) do
    persist_cache(subscription, %{cached_at: DateTime.utc_now(), last_error: nil})
  end

  defp handle_refresh_response(
         subscription,
         %Req.Response{status: 200, body: body} = response
       )
       when is_binary(body) do
    with {:ok, calendar_data} <-
           Fetch.parse_calendar(subscription, body, Fetch.response_etag(response)),
         :ok <-
           upsert_materialized_events(
             subscription,
             calendar_data.calendar,
             calendar_data.cached_name,
             calendar_data.raw_event_metadata
           ),
         {:ok, updated_subscription} <-
           persist_cache(subscription, %{
             cached_at: calendar_data.cached_at,
             etag: calendar_data.etag,
             last_error: nil,
             cached_name: calendar_data.cached_name,
             cached_tz: calendar_data.cached_tz,
             cached_desc: calendar_data.cached_desc
           }) do
      {:ok, updated_subscription}
    else
      {:error, error} when is_binary(error) ->
        handle_refresh_error(subscription, error)

      {:error, error} ->
        {:error, Exception.message(error)}
    end
  end

  defp handle_refresh_response(subscription, %Req.Response{status: status}) do
    handle_refresh_error(subscription, "Fetch failed with HTTP #{status}")
  end

  defp handle_refresh_error(subscription, error) do
    case persist_cache(subscription, %{last_error: error}) do
      {:ok, updated_subscription} -> {:error, updated_subscription.last_error}
      {:error, _persist_error} -> {:error, error}
    end
  end

  defp upsert_materialized_events(subscription, calendar, calendar_name, raw_event_metadata) do
    seen_at = DateTime.utc_now()

    attrs =
      materialized_events(subscription, calendar, calendar_name, raw_event_metadata)
      |> Enum.map(&Map.put(&1, :last_seen_at, seen_at))

    try do
      case Repo.transaction(fn ->
             if attrs != [] do
               Repo.insert_all(
                 ExternalEvent,
                 attrs,
                 on_conflict: {:replace_all_except, [:id, :inserted_at]},
                 conflict_target: [
                   :space_id,
                   :subscription_id,
                   :external_uid,
                   :external_occurrence_key
                 ]
               )
             end

             keep_occurrences =
               attrs
               |> Enum.map(&{&1.external_uid, &1.external_occurrence_key})
               |> MapSet.new()

             from(event in ExternalEvent, where: event.subscription_id == ^subscription.id)
             |> Repo.all()
             |> Enum.reject(fn event ->
               MapSet.member?(
                 keep_occurrences,
                 {event.external_uid, event.external_occurrence_key}
               )
             end)
             |> Enum.reduce_while(:ok, fn event, :ok ->
               case Repo.delete(event) do
                 {:ok, _deleted_event} ->
                   {:cont, :ok}

                 {:error, error} ->
                   Repo.rollback(error)
               end
             end)
           end) do
        {:ok, _result} ->
          :ok

        {:error, error} ->
          {:error, "Failed to persist external events: #{format_transaction_error(error)}"}
      end
    rescue
      error ->
        {:error, "Failed to persist external events: #{Exception.message(error)}"}
    end
  end

  defp materialized_events_for_uid(subscription, events, calendar_name, raw_event_metadata) do
    {overrides, bases} =
      Enum.split_with(events, &(not is_nil(&1.recurrence_id)))

    override_by_key = Map.new(overrides, &{occurrence_key(&1.recurrence_id), &1})

    base_occurrences =
      bases
      |> Enum.flat_map(fn event ->
        occurrences_for_event(event, override_by_key, raw_event_metadata)
        |> Enum.map(fn {starts_at, base_or_override_event, occurrence_key_value} ->
          materialized_event_attrs(
            subscription,
            base_or_override_event,
            starts_at,
            calendar_name,
            occurrence_key_value
          )
        end)
      end)

    override_only_occurrences =
      override_by_key
      |> Enum.reject(fn {key, _event} ->
        Enum.any?(base_occurrences, &(&1.external_occurrence_key == key))
      end)
      |> Enum.flat_map(fn {occurrence_key_value, event} ->
        case event.dtstart do
          nil ->
            log_unscheduled_ics_event(event)
            []

          dtstart ->
            starts_at = normalize_datetime!(dtstart)

            [
              materialized_event_attrs(
                subscription,
                event,
                starts_at,
                calendar_name,
                occurrence_key_value
              )
            ]
        end
      end)

    base_occurrences ++ override_only_occurrences
  end

  defp occurrences_for_event(
         %ICal.Event{dtstart: nil} = event,
         _override_by_key,
         _raw_event_metadata
       ) do
    log_unscheduled_ics_event(event)
    []
  end

  defp occurrences_for_event(event, override_by_key, raw_event_metadata) do
    horizon_start = recent_past_start()
    horizon_end = materialization_horizon_end()
    raw_until = raw_until_for_event(event, raw_event_metadata)

    cond do
      recurring_event?(event) ->
        event
        |> ICal.Recurrence.stream(start_date: event.dtstart, end_date: horizon_end)
        |> Enum.reduce([], fn recurrence_start, acc ->
          occurrence_key_value = occurrence_key(recurrence_start)
          override_event = Map.get(override_by_key, occurrence_key_value)

          occurrence_event =
            case override_event do
              %ICal.Event{} = override_event ->
                override_event

              nil ->
                ICal.Recurrence.apply(recurrence_start, event)
            end

          starts_at =
            occurrence_event.dtstart
            |> normalize_datetime!()

          if within_raw_until?(occurrence_event.dtstart, raw_until) and
               DateTime.compare(starts_at, horizon_start) in [:eq, :gt] and
               DateTime.compare(starts_at, horizon_end) in [:eq, :lt] do
            [{starts_at, occurrence_event, occurrence_key_value} | acc]
          else
            acc
          end
        end)
        |> Enum.reverse()

      true ->
        starts_at = normalize_datetime!(event.dtstart)

        if within_materialization_horizon?(starts_at) do
          [{starts_at, event, "single"}]
        else
          []
        end
    end
  end

  defp recurring_event?(event) do
    event.rrule != nil or event.rdates != [] or event.exdates != []
  end

  defp within_materialization_horizon?(starts_at) do
    DateTime.compare(starts_at, recent_past_start()) in [:eq, :gt] and
      DateTime.compare(starts_at, materialization_horizon_end()) in [:eq, :lt]
  end

  defp materialized_event_attrs(
         subscription,
         event,
         starts_at,
         calendar_name,
         occurrence_key_value
       ) do
    all_day? = match?(%Date{}, event.dtstart)
    ends_at = normalize_ends_at(event, starts_at, all_day?)
    event_uid = event.uid || fallback_uid(event)

    %{
      id: Ash.UUIDv7.generate(),
      space_id: subscription.space_id,
      subscription_id: subscription.id,
      external_uid: event_uid,
      external_recurrence_id: normalize_recurrence_id(event.recurrence_id),
      external_occurrence_key: occurrence_key_value,
      title: event.summary || "Untitled external event",
      starts_at: starts_at,
      ends_at: ends_at,
      all_day: all_day?,
      tz: timezone_for_event(event),
      status: external_status(event.status),
      location: Values.blank_to_nil(event.location),
      description: Values.blank_to_nil(event.description),
      event_url: Values.blank_to_nil(event.url),
      calendar_name: Values.blank_to_nil(calendar_name),
      source_missing_at: nil
    }
  end

  defp persist_cache(subscription, attrs) do
    Ash.update(
      subscription,
      attrs,
      action: :update_cache,
      authorize?: false,
      scope: %{tenant: subscription.space_id}
    )
  end

  defp fallback_uid(event) do
    [event.summary || "untitled", inspect(event.dtstart)]
    |> Enum.join(":")
  end

  defp log_unscheduled_ics_event(event) do
    Logger.warning(
      "Skipped unscheduled ICS event uid=#{inspect(event.uid)} summary=#{inspect(event.summary)}"
    )
  end

  defp occurrence_key(%DateTime{} = recurrence) do
    recurrence
    |> DateTime.shift_zone!(@default_tz)
    |> Calendar.strftime("%Y%m%dT%H%M%SZ")
  end

  defp occurrence_key(%Date{} = recurrence) do
    Calendar.strftime(recurrence, "%Y%m%d")
  end

  defp normalize_recurrence_id(nil), do: nil
  defp normalize_recurrence_id(recurrence_id), do: occurrence_key(recurrence_id)

  defp raw_until_for_event(event, raw_event_metadata) do
    Map.get(raw_event_metadata, event.uid || fallback_uid(event))
  end

  defp format_transaction_error(%{errors: _errors} = error), do: Exception.message(error)
  defp format_transaction_error(error) when is_binary(error), do: error
  defp format_transaction_error(error), do: inspect(error)

  defp sync_subscription_safely(subscription, opts) do
    sync_subscription(subscription, opts)
  rescue
    error ->
      Logger.error(
        "external calendar sync crashed for subscription #{subscription.id}: " <>
          Exception.format(:error, error, __STACKTRACE__)
      )

      {:error, subscription.id, Exception.message(error)}
  end

  defp external_status(nil), do: :published
  defp external_status(:confirmed), do: :published
  defp external_status(:tentative), do: :draft
  defp external_status(:cancelled), do: :cancelled

  defp timezone_for_event(%ICal.Event{dtstart: %DateTime{time_zone: tz}}),
    do: Values.blank_to_nil(tz) || @default_tz

  defp timezone_for_event(_event), do: @default_tz

  defp normalize_datetime!(%DateTime{} = datetime),
    do: datetime |> DateTime.shift_zone!(@default_tz) |> with_utc_usec()

  defp normalize_datetime!(%Date{} = date) do
    DateTime.new!(date, ~T[00:00:00], @default_tz)
    |> with_utc_usec()
  end

  defp normalize_ends_at(%ICal.Event{dtend: nil}, starts_at, false), do: starts_at
  defp normalize_ends_at(%ICal.Event{dtend: nil}, starts_at, true), do: starts_at

  defp normalize_ends_at(%ICal.Event{dtend: %Date{} = end_date}, _starts_at, true) do
    end_date
    |> Date.add(-1)
    |> DateTime.new!(~T[00:00:00], @default_tz)
    |> with_utc_usec()
  end

  defp normalize_ends_at(%ICal.Event{dtend: dtend}, _starts_at, _all_day?) do
    normalize_datetime!(dtend)
  end

  defp with_utc_usec(%DateTime{} = datetime) do
    %{datetime | microsecond: {0, 6}}
  end

  defp within_raw_until?(_dtstart, nil), do: true

  defp within_raw_until?(%Date{} = dtstart, %Date{} = until_date) do
    Date.compare(dtstart, until_date) in [:lt, :eq]
  end

  defp within_raw_until?(%Date{} = dtstart, %DateTime{} = until_datetime) do
    Date.compare(dtstart, DateTime.to_date(until_datetime)) in [:lt, :eq]
  end

  defp within_raw_until?(%DateTime{} = dtstart, %Date{} = until_date) do
    Date.compare(DateTime.to_date(dtstart), until_date) in [:lt, :eq]
  end

  defp within_raw_until?(%DateTime{} = dtstart, %DateTime{} = until_datetime) do
    DateTime.compare(normalize_datetime!(dtstart), normalize_datetime!(until_datetime)) in [
      :lt,
      :eq
    ]
  end
end
