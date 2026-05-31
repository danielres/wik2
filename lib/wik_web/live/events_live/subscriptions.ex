defmodule WikWeb.EventsLive.Subscriptions do
  alias Phoenix.Component
  alias Wik.Events.ExternalCalendar

  def empty do
    %{
      records: [],
      errors_by_id: %{},
      names_by_id: %{},
      metadata_by_id: %{}
    }
  end

  def create_form(ics_url \\ "") do
    Component.to_form(%{"ics_url" => ics_url}, as: :subscription)
  end

  def name_form(nil) do
    Component.to_form(%{"id" => nil, "custom_name" => nil}, as: :subscription_name)
  end

  def name_form(subscription) do
    Component.to_form(
      %{"id" => subscription.id, "custom_name" => subscription.custom_name},
      as: :subscription_name
    )
  end

  def put_loaded_data(state, loaded_data) do
    %{
      state
      | records: loaded_data.subscription_records,
        errors_by_id: loaded_data.subscription_errors_by_id,
        names_by_id: loaded_data.subscription_names_by_id,
        metadata_by_id: loaded_data.subscription_metadata_by_id
    }
  end

  def display_name(state, subscription) do
    ExternalCalendar.display_name(subscription, Map.get(state.names_by_id, subscription.id))
  end

  def sorted(state) do
    Enum.sort_by(state.records, fn subscription ->
      display_name(state, subscription)
      |> String.downcase()
    end)
  end

  def title(_state, nil), do: "Unnamed calendar"

  def title(state, subscription) do
    case display_name(state, subscription) |> blank_to_nil() do
      nil -> "Unnamed calendar"
      name -> name
    end
  end

  def find(state, id) do
    Enum.find(state.records, &(&1.id == id))
  end

  def metadata(state, subscription) do
    Map.get(state.metadata_by_id, subscription.id, %{name: nil, timezone: nil, description: nil})
  end

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value
end
