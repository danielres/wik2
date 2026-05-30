defmodule Wik.Events.ExternalCalendar do
  @moduledoc """
  Fetches, caches, parses, and normalizes external ICS calendar feeds.

  This module also owns the display-name precedence for subscribed calendars:

  1. `subscription.custom_name`
  2. parsed ICS calendar name
  3. subscription ICS URL
  """

  alias Wik.Events.ExternalCalendarSubscription

  @cache_ttl_seconds 60 * 60
  @default_tz "Etc/UTC"

  def fetch_subscription_cache(subscription, http_get \\ http_get()) do
    with {:ok, calendar_data} <- fetch_remote_calendar(subscription, http_get) do
      {:ok, Map.take(calendar_data, [:cached_body, :cached_at, :etag])}
    end
  end

  def fetch_subscription_events(subscription, http_get \\ http_get()) do
    with {:ok, calendar_data} <- fetch_remote_calendar(subscription, http_get) do
      {:ok, timeline_items(subscription, calendar_data.calendar, calendar_data.display_name)}
    end
  end

  def load_subscriptions(subscriptions, opts \\ []) do
    refresh? = Keyword.get(opts, :refresh?, true)

    Enum.reduce(
      subscriptions,
      %{events: [], errors_by_id: %{}, names_by_id: %{}, records: []},
      fn subscription, acc ->
        case load_subscription(subscription, refresh?: refresh?) do
          {:ok, loaded_subscription} ->
            acc
            |> Map.update!(:events, &(&1 ++ loaded_subscription.events))
            |> Map.update!(:records, &(&1 ++ [loaded_subscription.subscription]))
            |> Map.update!(:names_by_id, &Map.put(&1, subscription.id, loaded_subscription.name))
            |> maybe_put_error(subscription.id, loaded_subscription.error)

          {:error, error} ->
            acc
            |> Map.update!(:records, &(&1 ++ [subscription]))
            |> Map.update!(:errors_by_id, &Map.put(&1, subscription.id, error))
        end
      end
    )
  end

  def load_subscription(subscription, opts \\ []) do
    http_get = Keyword.get(opts, :http_get, http_get())
    refresh? = Keyword.get(opts, :refresh?, true)

    cond do
      fresh_cache?(subscription) ->
        load_cached_subscription(subscription)

      not refresh? ->
        load_cached_subscription(subscription)

      true ->
        refresh_subscription(subscription, http_get)
    end
  end

  def display_name(subscription, calendar_name \\ nil)

  def display_name(calendar_name, subscription)
      when is_binary(calendar_name) or is_nil(calendar_name) do
    display_name(subscription, calendar_name)
  end

  def display_name(subscription, calendar_name) do
    case blank_to_nil(subscription.custom_name) do
      nil -> blank_to_nil(calendar_name) || subscription.ics_url
      custom_name -> custom_name
    end
  end

  defp refresh_subscription(subscription, http_get) do
    with {:ok, response} <- http_get.(subscription.ics_url, refresh_request_options(subscription)) do
      handle_refresh_response(subscription, response, http_get)
    else
      {:error, error} ->
        handle_refresh_error(subscription, "Fetch failed: #{Exception.message(error)}")

      _ ->
        handle_refresh_error(subscription, "Calendar feed response was invalid")
    end
  end

  defp handle_refresh_response(subscription, %Req.Response{status: 304}, _http_get) do
    attrs = %{cached_at: DateTime.utc_now(), last_error: nil}

    case persist_cache(subscription, attrs) do
      {:ok, _updated_subscription} ->
        load_cached_subscription(apply_cache_attrs(subscription, attrs))

      {:error, error} ->
        {:error, Exception.message(error)}
    end
  end

  defp handle_refresh_response(
         subscription,
         %Req.Response{status: 200, body: body} = response,
         _http_get
       )
       when is_binary(body) do
    with {:ok, calendar_data} <- parse_calendar(subscription, body),
         {:ok, _updated_subscription} <-
           persist_cache(subscription, %{
             cached_body: body,
             cached_at: calendar_data.cached_at,
             etag: response_etag(response),
             last_error: nil
           }) do
      loaded_subscription =
        apply_cache_attrs(subscription, %{
          cached_body: body,
          cached_at: calendar_data.cached_at,
          etag: response_etag(response),
          last_error: nil
        })

      {:ok,
       %{
         subscription: loaded_subscription,
         events:
           timeline_items(
             loaded_subscription,
             calendar_data.calendar,
             calendar_data.display_name
           ),
         name: calendar_data.display_name,
         error: nil
       }}
    else
      {:error, error} when is_binary(error) ->
        handle_refresh_error(subscription, error)

      {:error, error} ->
        {:error, Exception.message(error)}
    end
  end

  defp handle_refresh_response(subscription, %Req.Response{status: status}, _http_get) do
    handle_refresh_error(subscription, "Fetch failed with HTTP #{status}")
  end

  defp handle_refresh_error(subscription, error) do
    case persist_cache(subscription, %{last_error: error}) do
      {:ok, _updated_subscription} when is_binary(subscription.cached_body) ->
        load_cached_subscription(apply_cache_attrs(subscription, %{last_error: error}))

      {:ok, _updated_subscription} ->
        {:error, error}

      {:error, _persist_error} ->
        {:error, error}
    end
  end

  defp load_cached_subscription(%ExternalCalendarSubscription{cached_body: body} = subscription)
       when is_binary(body) do
    with {:ok, calendar_data} <- parse_calendar(subscription, body) do
      {:ok,
       %{
         subscription: subscription,
         events: timeline_items(subscription, calendar_data.calendar, calendar_data.display_name),
         name: calendar_data.display_name,
         error: subscription.last_error
       }}
    end
  end

  defp load_cached_subscription(_subscription), do: {:error, "Calendar has not been cached yet"}

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

  defp parse_calendar(subscription, body, etag \\ nil) do
    calendar = ICal.from_ics(body)
    calendar_name = calendar_name(calendar)

    {:ok,
     %{
       calendar: calendar,
       display_name: display_name(subscription, calendar_name),
       cached_body: body,
       cached_at: DateTime.utc_now(),
       etag: etag
     }}
  rescue
    error ->
      {:error, "Calendar parse failed: #{Exception.message(error)}"}
  end

  defp timeline_items(subscription, calendar, display_name) do
    now = DateTime.utc_now()

    calendar.events
    |> Enum.flat_map(&timeline_items_for_event(subscription, &1, display_name))
    |> Enum.filter(&(DateTime.compare(&1.starts_at, now) in [:eq, :gt]))
    |> Enum.sort_by(&{DateTime.to_unix(&1.starts_at, :microsecond), &1.id})
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

  defp fresh_cache?(subscription) do
    match?(%DateTime{}, subscription.cached_at) and
      is_binary(subscription.cached_body) and
      DateTime.diff(DateTime.utc_now(), subscription.cached_at, :second) < @cache_ttl_seconds
  end

  defp apply_cache_attrs(subscription, attrs) do
    struct!(subscription, attrs)
  end

  defp maybe_put_error(acc, _subscription_id, nil), do: acc

  defp maybe_put_error(acc, subscription_id, error) do
    Map.update!(acc, :errors_by_id, &Map.put(&1, subscription_id, error))
  end

  defp http_get do
    Application.get_env(:wik, __MODULE__, [])
    |> Keyword.get(:http_get, &Req.get/2)
  end

  defp timeline_items_for_event(_subscription, %ICal.Event{dtstart: nil}, _calendar_name), do: []

  defp timeline_items_for_event(subscription, event, calendar_name) do
    all_day? = match?(%Date{}, event.dtstart)
    starts_at = normalize_datetime!(event.dtstart)
    ends_at = normalize_ends_at(event, starts_at, all_day?)

    [
      %{
        id: external_item_id(subscription, event, starts_at),
        source_type: :external,
        title: event.summary || "Untitled external event",
        starts_at: starts_at,
        ends_at: ends_at,
        all_day: all_day?,
        tz: timezone_for_event(event),
        status: external_status(event.status),
        location: event.location,
        description: event.description,
        publication_id: nil,
        publication_type: nil,
        event_url: event.url,
        external_uid: event.uid,
        space_slug: subscription.space.slug,
        source_name: source_name(subscription),
        calendar_name: calendar_name,
        source_url: subscription.ics_url,
        subscription_id: subscription.id
      }
    ]
  end

  defp external_item_id(subscription, event, starts_at) do
    event_uid = event.uid || Calendar.strftime(starts_at, "%Y%m%dT%H%M%S")
    "external:#{subscription.id}:#{event_uid}"
  end

  defp source_name(subscription) do
    subscription.ics_url
    |> URI.parse()
    |> Map.get(:host)
    |> case do
      nil -> subscription.ics_url
      host -> host
    end
  end

  defp calendar_name(%ICal{name: name}) when is_binary(name), do: name
  defp calendar_name(_calendar), do: nil

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value

  defp external_status(nil), do: :published
  defp external_status(:confirmed), do: :published
  defp external_status(:tentative), do: :draft
  defp external_status(:cancelled), do: :cancelled

  defp timezone_for_event(%ICal.Event{dtstart: %DateTime{time_zone: tz}}), do: tz
  defp timezone_for_event(_event), do: @default_tz

  defp normalize_datetime!(%DateTime{} = datetime),
    do: DateTime.shift_zone!(datetime, @default_tz)

  defp normalize_datetime!(%Date{} = date) do
    DateTime.new!(date, ~T[00:00:00], @default_tz)
  end

  defp normalize_ends_at(%ICal.Event{dtend: nil}, starts_at, false), do: starts_at
  defp normalize_ends_at(%ICal.Event{dtend: nil}, starts_at, true), do: starts_at

  defp normalize_ends_at(%ICal.Event{dtend: %Date{} = end_date}, _starts_at, true) do
    end_date
    |> Date.add(-1)
    |> DateTime.new!(~T[00:00:00], @default_tz)
  end

  defp normalize_ends_at(%ICal.Event{dtend: dtend}, _starts_at, _all_day?) do
    normalize_datetime!(dtend)
  end
end
