defmodule Utils.Tz do
  def valid?(tz) when is_binary(tz) and tz != "" do
    match?({:ok, _}, DateTime.now(tz))
  end

  def valid?(_tz), do: false

  def to_local!(%DateTime{} = datetime, tz) when is_binary(tz) do
    case DateTime.shift_zone(datetime, tz) do
      {:ok, local} ->
        local

      {:error, reason} ->
        raise ArgumentError, "could not shift #{inspect(datetime)} to #{tz}: #{inspect(reason)}"
    end
  end

  def from_local(date_value, time_value, tz) when is_binary(tz) do
    with date when not is_nil(date) <- blank_to_nil(date_value),
         time when not is_nil(time) <- blank_to_nil(time_value),
         {:ok, date} <- parse_date(date),
         {:ok, time} <- parse_time(time),
         naive <- NaiveDateTime.new!(date, time),
         {:ok, local} <- DateTime.from_naive(naive, tz),
         {:ok, utc} <- DateTime.shift_zone(local, "Etc/UTC") do
      utc
    else
      {:ambiguous, local, _other} ->
        {:ok, utc} = DateTime.shift_zone(local, "Etc/UTC")
        utc

      _ ->
        nil
    end
  end

  def parse_date(%Date{} = date), do: {:ok, date}
  def parse_date(%NaiveDateTime{} = datetime), do: {:ok, NaiveDateTime.to_date(datetime)}
  def parse_date(%DateTime{} = datetime), do: {:ok, DateTime.to_date(datetime)}
  def parse_date(date_string) when is_binary(date_string), do: Date.from_iso8601(date_string)

  def parse_time(%Time{} = time), do: {:ok, time}
  def parse_time(%NaiveDateTime{} = datetime), do: {:ok, NaiveDateTime.to_time(datetime)}
  def parse_time(%DateTime{} = datetime), do: {:ok, DateTime.to_time(datetime)}

  def parse_time(time_string) when is_binary(time_string) do
    Time.from_iso8601(time_string <> ":00")
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value
end
