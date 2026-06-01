defmodule Wik.Events.ExternalCalendar.Presentation do
  @moduledoc false

  alias Utils.Values

  def load_subscriptions(subscriptions, _opts \\ []) do
    %{
      records: subscriptions,
      errors_by_id:
        subscriptions
        |> Enum.flat_map(fn subscription ->
          case Values.blank_to_nil(subscription.last_error) do
            nil -> []
            error -> [{subscription.id, error}]
          end
        end)
        |> Map.new(),
      names_by_id:
        subscriptions
        |> Enum.flat_map(fn subscription ->
          case Values.blank_to_nil(subscription.cached_name) do
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

  def display_name(subscription, calendar_name) do
    case Values.blank_to_nil(subscription.custom_name) do
      nil ->
        Values.blank_to_nil(calendar_name) ||
          Values.blank_to_nil(subscription.cached_name) ||
          subscription.ics_url

      custom_name ->
        custom_name
    end
  end

  defp calendar_metadata(subscription) do
    %{
      name: Values.blank_to_nil(subscription.cached_name),
      timezone: Values.blank_to_nil(subscription.cached_tz),
      description: Values.blank_to_nil(subscription.cached_desc)
    }
  end
end
