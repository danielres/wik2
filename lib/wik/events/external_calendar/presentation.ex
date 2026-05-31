defmodule Wik.Events.ExternalCalendar.Presentation do
  @moduledoc false

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

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value
end
