defmodule WikWeb.EventsLive.Params do
  @moduledoc false

  def parse(params) do
    %{
      show_external?: parse_show_external?(params),
      future_windows: parse_future_windows(params["future_windows"])
    }
  end

  def page_params(show_external?, future_windows) do
    %{external: show_external?}
    |> maybe_put_future_windows(future_windows)
  end

  def event_params(event_id, show_external?, future_windows) do
    %{event: event_id, external: show_external?}
    |> maybe_put_future_windows(future_windows)
  end

  def load_more_params(show_external?, future_windows) do
    %{external: show_external?, future_windows: future_windows + 1}
  end

  defp parse_show_external?(%{"external" => value}),
    do: value in [true, "true", "on", "1"]

  defp parse_show_external?(_params), do: false

  defp parse_future_windows(nil), do: 1

  defp parse_future_windows(value) do
    case Integer.parse(to_string(value)) do
      {int, ""} when int > 0 -> int
      _ -> 1
    end
  end

  defp maybe_put_future_windows(params, future_windows) when future_windows > 1 do
    Map.put(params, :future_windows, future_windows)
  end

  defp maybe_put_future_windows(params, _future_windows), do: params
end
