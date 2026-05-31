defmodule Wik.Events.ExternalCalendar.Fetch do
  @moduledoc false

  alias Wik.Events.ExternalCalendar.Presentation

  def fetch_subscription_cache(subscription, http_get \\ http_get()) do
    with {:ok, calendar_data} <- fetch_remote_calendar(subscription, http_get) do
      {:ok,
       Map.take(calendar_data, [
         :cached_at,
         :etag,
         :cached_name,
         :cached_tz,
         :cached_desc
       ])}
    end
  end

  def fetch_remote_calendar(subscription, http_get) do
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

  def parse_calendar(subscription, body, etag) do
    calendar = ICal.from_ics(body)
    calendar_metadata = parse_calendar_metadata(body, calendar)

    {:ok,
     %{
       calendar: calendar,
       cached_at: DateTime.utc_now(),
       etag: etag,
       cached_name: calendar_metadata.name,
       cached_tz: calendar_metadata.timezone,
       cached_desc: calendar_metadata.description,
       raw_event_metadata: parse_raw_event_metadata(body),
       display_name: Presentation.display_name(subscription, calendar_metadata.name)
     }}
  rescue
    error ->
      {:error, "Calendar parse failed: #{Exception.message(error)}"}
  end

  def refresh_request_options(subscription) do
    case blank_to_nil(subscription.etag) do
      nil -> []
      etag -> [headers: [{"if-none-match", etag}]]
    end
  end

  def response_etag(response) do
    response
    |> Req.Response.get_header("etag")
    |> List.first()
    |> blank_to_nil()
  end

  def http_get do
    Application.get_env(:wik, Wik.Events.ExternalCalendar, [])
    |> Keyword.get(:http_get, &Req.get/2)
  end

  defp calendar_name(%ICal{name: name}) when is_binary(name), do: name
  defp calendar_name(_calendar), do: nil

  defp parse_calendar_metadata(body, calendar) do
    unfolded_body = unfold_ics_lines(body)

    %{
      name:
        blank_to_nil(calendar_name(calendar)) ||
          capture_calendar_property(unfolded_body, "X-WR-CALNAME"),
      timezone: capture_calendar_property(unfolded_body, "X-WR-TIMEZONE"),
      description:
        unfolded_body
        |> capture_calendar_property("X-WR-CALDESC")
        |> decode_ics_text()
    }
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

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value
end
