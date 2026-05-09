defmodule WikWeb.Components.LocationPicker do
  use WikWeb, :html

  alias Wik.Locations
  alias WikWeb.Components.Combobox
  alias WikWeb.CoreComponents

  attr :field, Phoenix.HTML.FormField, required: true
  attr :id, :string, default: nil
  attr :label, :string, required: true
  attr :placeholder, :string, default: "Search locations"
  attr :testid, :string, default: nil

  def field(assigns) do
    value = field_value(assigns.field)

    assigns =
      assigns
      |> assign(:display_value, value || "")
      |> assign(:enabled?, Locations.enabled?())
      |> assign(:errors, Enum.map(assigns.field.errors, &CoreComponents.translate_error/1))

    ~H"""
    <Combobox.field
      :if={@enabled?}
      debounce_ms={300}
      display_value={@display_value}
      empty_display="Add location"
      empty_message="No matching location"
      errors={@errors}
      field={@field}
      free_text={true}
      id={@id}
      label={@label}
      placeholder={@placeholder}
      search_event="location_search"
      suggested_values_json="[]"
      testid={@testid}
    />

    <.input :if={not @enabled?} field={@field} label={@label} />
    """
  end

  defp field_value(field) do
    Phoenix.HTML.Form.input_value(field.form, field.field)
  end
end
