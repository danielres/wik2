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
          case blank_to_nil(subscription.cached_name) do
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
          blank_to_nil(subscription.cached_name) ||
          subscription.ics_url

      custom_name ->
        custom_name
    end
  end

  defp calendar_metadata(subscription) do
    %{
      name: blank_to_nil(subscription.cached_name),
      timezone: blank_to_nil(subscription.cached_tz),
      description: blank_to_nil(subscription.cached_desc)
    }
  end

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value
end
