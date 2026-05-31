defmodule Wik.Events.ExternalCalendar do
  @moduledoc """
  Fetches, parses, expands, and materializes external ICS calendar feeds.

  This module also owns the display-name precedence for subscribed calendars:

  1. `subscription.custom_name`
  2. `subscription.cached_calendar_name`
  3. subscription ICS URL
  """

  import Ecto.Query, only: [from: 2]

  alias Wik.Events.ExternalCalendarSubscription
  alias Wik.Events.ExternalEvent
  alias Wik.Repo

  @default_tz "Etc/UTC"
  @future_horizon_months 12
  @recent_past_days 30

  def fetch_subscription_cache(subscription, http_get \\ http_get()) do
    with {:ok, calendar_data} <- fetch_remote_calendar(subscription, http_get) do
      {:ok, Map.take(calendar_data, [:cached_body, :cached_at, :etag, :cached_calendar_name])}
    end
  end

  def fetch_subscription_events(subscription, http_get \\ http_get()) do
    with {:ok, calendar_data} <- fetch_remote_calendar(subscription, http_get) do
      {:ok,
       materialized_events(
         subscription,
         calendar_data.calendar,
         calendar_data.cached_calendar_name,
         calendar_data.raw_event_metadata
       )}
    end
  end

  def load_subscriptions(subscriptions, _opts \\ []) do
    %{
      records: subscriptions,
      errors_by_id:
        subscriptions
        |> Enum.flat_map(fn subscription ->
          case blank_to_nil(subscription.last_error) do
            nil -> []
            error -> [{subscription.id, error}]
          end
        end)
        |> Map.new(),
      names_by_id:
        subscriptions
        |> Enum.flat_map(fn subscription ->
          case blank_to_nil(subscription.cached_calendar_name) do
            nil -> []
            name -> [{subscription.id, name}]
          end
        end)
        |> Map.new(),
      metadata_by_id:
        subscriptions
        |> Enum.map(fn subscription ->
          {subscription.id, calendar_metadata(subscription)}
        end)
        |> Map.new()
    }
  end

  def sync_subscription(%ExternalCalendarSubscription{} = subscription, opts \\ []) do
    http_get = Keyword.get(opts, :http_get, http_get())

    with {:ok, response} <- http_get.(subscription.ics_url, refresh_request_options(subscription)) do
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
    |> Task.async_stream(&sync_subscription(&1, opts), timeout: :infinity)
    |> Stream.run()

    :ok
  end

  def display_name(subscription, calendar_name \\ nil)

  def display_name(calendar_name, subscription)
      when is_binary(calendar_name) or is_nil(calendar_name) do
    display_name(subscription, calendar_name)
  end

  def display_name(subscription, calendar_name) do
    case blank_to_nil(subscription.custom_name) do
      nil ->
        blank_to_nil(calendar_name) ||
          blank_to_nil(subscription.cached_calendar_name) ||
          subscription.ics_url

      custom_name ->
        custom_name
    end
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

  defp handle_refresh_response(subscription, %Req.Response{status: 304}) do
    persist_cache(subscription, %{cached_at: DateTime.utc_now(), last_error: nil})
  end

  defp handle_refresh_response(
         subscription,
         %Req.Response{status: 200, body: body} = response
       )
       when is_binary(body) do
    with {:ok, calendar_data} <- parse_calendar(subscription, body, response_etag(response)),
         :ok <-
           upsert_materialized_events(
             subscription,
             calendar_data.calendar,
             calendar_data.cached_calendar_name,
             calendar_data.raw_event_metadata
           ),
         {:ok, updated_subscription} <-
           persist_cache(subscription, %{
             cached_body: body,
             cached_at: calendar_data.cached_at,
             etag: calendar_data.etag,
             last_error: nil,
             cached_calendar_name: calendar_data.cached_calendar_name
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

  defp fetch_remote_calendar(subscription, http_get) do
    with {:ok, response} <- http_get.(subscription.ics_url, []),
         200 <- response.status,
         body when is_binary(body) <- response.body do
      parse_calendar(subscription, body, response_etag(response))
    else
      {:ok, response} ->
        {:error, "Fetch failed with HTTP #{response.status}"}

      {:error, error} ->
        {:error, "Fetch failed: #{Exception.message(error)}"}

      _ ->
        {:error, "Calendar feed response was invalid"}
    end
  end

  defp parse_calendar(subscription, body, etag) do
    calendar = ICal.from_ics(body)
    calendar_name = calendar_name(calendar)

    {:ok,
     %{
       calendar: calendar,
       cached_body: body,
       cached_at: DateTime.utc_now(),
       etag: etag,
       cached_calendar_name: blank_to_nil(calendar_name),
       raw_event_metadata: parse_raw_event_metadata(body),
       display_name: display_name(subscription, calendar_name)
     }}
  rescue
    error ->
      {:error, "Calendar parse failed: #{Exception.message(error)}"}
  end

  defp upsert_materialized_events(subscription, calendar, calendar_name, raw_event_metadata) do
    seen_at = DateTime.utc_now()

    attrs =
      materialized_events(subscription, calendar, calendar_name, raw_event_metadata)
      |> Enum.map(&Map.put(&1, :last_seen_at, seen_at))

    Repo.transaction(fn ->
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
        MapSet.member?(keep_occurrences, {event.external_uid, event.external_occurrence_key})
      end)
      |> Enum.each(&Repo.delete!/1)
    end)

    :ok
  end

  defp materialized_events(subscription, calendar, calendar_name, raw_event_metadata) do
    calendar.events
    |> Enum.group_by(&(&1.uid || fallback_uid(&1)))
    |> Enum.flat_map(fn {_uid, events} ->
      materialized_events_for_uid(subscription, events, calendar_name, raw_event_metadata)
    end)
    |> Enum.sort_by(&{DateTime.to_unix(&1.starts_at, :microsecond), &1.id})
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
      |> Enum.map(fn {occurrence_key_value, event} ->
        starts_at = normalize_datetime!(event.dtstart)

        materialized_event_attrs(
          subscription,
          event,
          starts_at,
          calendar_name,
          occurrence_key_value
        )
      end)

    base_occurrences ++ override_only_occurrences
  end

  defp occurrences_for_event(%ICal.Event{dtstart: nil}, _override_by_key, _raw_event_metadata),
    do: []

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
      location: blank_to_nil(event.location),
      description: blank_to_nil(event.description),
      event_url: blank_to_nil(event.url),
      calendar_name: blank_to_nil(calendar_name)
    }
  end

  defp refresh_request_options(subscription) do
    case blank_to_nil(subscription.etag) do
      nil -> []
      etag -> [headers: [{"if-none-match", etag}]]
    end
  end

  defp response_etag(response) do
    response
    |> Req.Response.get_header("etag")
    |> List.first()
    |> blank_to_nil()
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

  defp http_get do
    Application.get_env(:wik, __MODULE__, [])
    |> Keyword.get(:http_get, &Req.get/2)
  end

  defp calendar_name(%ICal{name: name}) when is_binary(name), do: name
  defp calendar_name(_calendar), do: nil

  defp fallback_uid(event) do
    [event.summary || "untitled", inspect(event.dtstart)]
    |> Enum.join(":")
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

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value

  defp external_status(nil), do: :published
  defp external_status(:confirmed), do: :published
  defp external_status(:tentative), do: :draft
  defp external_status(:cancelled), do: :cancelled

  defp timezone_for_event(%ICal.Event{dtstart: %DateTime{time_zone: tz}}),
    do: blank_to_nil(tz) || @default_tz

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

  defp parse_raw_event_metadata(body) do
    body
    |> unfold_ics_lines()
    |> String.split("BEGIN:VEVENT\n", trim: true)
    |> Enum.reduce(%{}, fn chunk, acc ->
      case String.split(chunk, "END:VEVENT", parts: 2) do
        [event_body, _rest] ->
          uid = capture_ics_value(event_body, ~r/^UID:(.+)$/m)
          rrule = capture_ics_value(event_body, ~r/^RRULE:(.+)$/m)

          case {uid, rrule && parse_until_from_rrule(rrule)} do
            {uid, until_value} when is_binary(uid) and not is_nil(until_value) ->
              Map.put(acc, uid, until_value)

            _ ->
              acc
          end

        _ ->
          acc
      end
    end)
  end

  defp unfold_ics_lines(body) do
    body
    |> String.replace("\r\n", "\n")
    |> String.replace(~r/\n[ \t]/, "")
  end

  defp capture_ics_value(body, regex) do
    case Regex.run(regex, body, capture: :all_but_first) do
      [value] -> value
      _ -> nil
    end
  end

  defp parse_until_from_rrule(rrule) do
    params =
      rrule
      |> String.split(";")
      |> Enum.map(fn pair ->
        case String.split(pair, "=", parts: 2) do
          [key, value] -> {key, value}
          [key] -> {key, nil}
        end
      end)
      |> Map.new()

    case Map.get(params, "UNTIL") do
      nil -> nil
      value -> parse_ics_until(value)
    end
  end

  defp parse_ics_until(<<year::binary-size(4), month::binary-size(2), day::binary-size(2)>>) do
    Date.from_iso8601!("#{year}-#{month}-#{day}")
  end

  defp parse_ics_until(
         <<year::binary-size(4), month::binary-size(2), day::binary-size(2), "T",
           hour::binary-size(2), minute::binary-size(2), second::binary-size(2), "Z">>
       ) do
    DateTime.from_naive!(
      NaiveDateTime.from_iso8601!("#{year}-#{month}-#{day} #{hour}:#{minute}:#{second}"),
      "Etc/UTC"
    )
  end

  defp parse_ics_until(
         <<year::binary-size(4), month::binary-size(2), day::binary-size(2), "T",
           hour::binary-size(2), minute::binary-size(2), second::binary-size(2)>>
       ) do
    DateTime.from_naive!(
      NaiveDateTime.from_iso8601!("#{year}-#{month}-#{day} #{hour}:#{minute}:#{second}"),
      "Etc/UTC"
    )
  end

  defp parse_ics_until(_value), do: nil

  defp calendar_metadata(subscription) do
    metadata =
      case blank_to_nil(subscription.cached_body) do
        nil ->
          empty_calendar_metadata()

        body ->
          body
          |> unfold_ics_lines()
          |> parse_calendar_metadata_from_body()
      end

    metadata
    |> Map.put_new(:name, blank_to_nil(subscription.cached_calendar_name))
    |> Map.put_new(:timezone, nil)
    |> Map.put_new(:description, nil)
  end

  defp parse_calendar_metadata_from_body(body) do
    %{
      name: capture_calendar_property(body, "X-WR-CALNAME"),
      timezone: capture_calendar_property(body, "X-WR-TIMEZONE"),
      description:
        body
        |> capture_calendar_property("X-WR-CALDESC")
        |> decode_ics_text()
    }
  end

  defp empty_calendar_metadata do
    %{name: nil, timezone: nil, description: nil}
  end

  defp capture_calendar_property(body, property) do
    body
    |> capture_ics_value(~r/^#{Regex.escape(property)}:(.+)$/m)
    |> blank_to_nil()
    |> decode_ics_text()
  end

  defp decode_ics_text(nil), do: nil

  defp decode_ics_text(value) do
    value
    |> String.replace("\\n", "\n")
    |> String.replace("\\N", "\n")
    |> String.replace("\\,", ",")
    |> String.replace("\\;", ";")
    |> blank_to_nil()
  end
end
