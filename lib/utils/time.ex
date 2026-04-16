defmodule Utils.Time do
  def precise(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end

  def relative(%DateTime{} = datetime) do
    datetime
    |> DateTime.diff(DateTime.utc_now(), :second)
    |> humanize_seconds()
  end

  def relative(%NaiveDateTime{} = datetime) do
    datetime
    |> NaiveDateTime.diff(NaiveDateTime.utc_now(), :second)
    |> humanize_seconds()
  end

  defp humanize_seconds(seconds) when abs(seconds) < 5, do: "just now"
  defp humanize_seconds(seconds) when abs(seconds) < 60, do: format(seconds, 1, "s")
  defp humanize_seconds(seconds) when abs(seconds) < 3_600, do: format(seconds, 60, "min")
  defp humanize_seconds(seconds) when abs(seconds) < 86_400, do: format(seconds, 3_600, "h")
  defp humanize_seconds(seconds) when abs(seconds) < 2_592_000, do: format(seconds, 86_400, "d")

  defp humanize_seconds(seconds) when abs(seconds) < 31_536_000,
    do: format(seconds, 2_592_000, "mo")

  defp humanize_seconds(seconds), do: format(seconds, 31_536_000, "y")

  defp format(seconds, unit_seconds, unit_name) do
    count = div(abs(seconds), unit_seconds)
    label = if count == 1, do: unit_name, else: "#{unit_name}"

    if seconds < 0 do
      # "#{count} #{label} ago"
      "#{count}#{label}"
    else
      "in #{count}#{label}"
    end
  end
end
