defmodule WikWeb.EventsLive.Params do
  @moduledoc false

  def parse(params) do
    %{
      event_id: parse_event_id(params),
      external_event_id: parse_external_event_id(params),
      show_external?: parse_show_external?(params),
      future_windows: parse_future_windows(params["future_windows"])
    }
  end

  def page_query(show_external?, future_windows),
    do: query([calendars_param(show_external?), future_windows_param(future_windows)])

  def event_query(event_id, show_external?, future_windows),
    do:
      query([
        calendars_param(show_external?),
        {"event", event_id},
        future_windows_param(future_windows)
      ])

  def external_event_query(external_event_id), do: external_event_query(external_event_id, 1)

  def external_event_query(external_event_id, future_windows),
    do: query([{"ext", external_event_id}, future_windows_param(future_windows)])

  def load_more_query(show_external?, future_windows),
    do: query([calendars_param(show_external?), {"future_windows", future_windows + 1}])

  defp parse_event_id(%{"event" => event_id}), do: event_id
  defp parse_event_id(_params), do: nil

  defp parse_external_event_id(%{"ext" => external_event_id}), do: external_event_id
  defp parse_external_event_id(_params), do: nil

  defp parse_show_external?(%{"ext" => _external_event_id}), do: true
  defp parse_show_external?(params), do: Map.has_key?(params, "calendars")

  defp parse_future_windows(nil), do: 1

  defp parse_future_windows(value) do
    case Integer.parse(to_string(value)) do
      {int, ""} when int > 0 -> int
      _ -> 1
    end
  end

  defp calendars_param(true), do: "calendars"
  defp calendars_param(false), do: nil

  defp future_windows_param(future_windows) when future_windows > 1,
    do: {"future_windows", future_windows}

  defp future_windows_param(_future_windows), do: nil

  defp query(parts) do
    parts
    |> Enum.reject(&is_nil/1)
    |> Enum.map_join("&", fn
      key when is_binary(key) ->
        URI.encode_www_form(key)

      {key, value} ->
        URI.encode_www_form(to_string(key)) <> "=" <> URI.encode_www_form(to_string(value))
    end)
  end
end
