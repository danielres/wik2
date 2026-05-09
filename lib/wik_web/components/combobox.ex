defmodule WikWeb.Components.Combobox do
  use WikWeb, :html

  attr :field, Phoenix.HTML.FormField, required: true
  attr :display_value, :string, default: nil
  attr :empty_display, :string, default: ""
  attr :empty_message, :string, default: "No matches"
  attr :errors, :list, default: []
  attr :free_text, :boolean, default: false
  attr :id, :string, default: nil
  attr :label, :string, required: true
  attr :options_json, :string, default: "[]"
  attr :placeholder, :string, default: "Search"
  attr :search_event, :string, default: nil
  attr :search_min_length, :integer, default: 1
  attr :suggested_values_json, :string, default: "[]"
  attr :testid, :string, default: nil

  def field(assigns) do
    field_value = field_value(assigns.field)

    display_value =
      cond do
        is_binary(assigns.display_value) ->
          assigns.display_value

        is_binary(field_value) and field_value != "" ->
          field_value

        true ->
          assigns.empty_display
      end

    assigns =
      assigns
      |> assign(:anchor_name, "--#{assigns.id || "#{assigns.field.id}-picker"}")
      |> assign(:display_id, "#{assigns.id || assigns.field.id}-display")
      |> assign(:display_value, display_value)
      |> assign(:field_value, field_value || "")
      |> assign(:picker_id, assigns.id || "#{assigns.field.id}-picker")

    ~H"""
    <div
      id={@picker_id}
      class="fieldset relative"
      data-empty-display={@empty_display}
      data-empty-message={@empty_message}
      data-free-text={to_string(@free_text)}
      data-options={@options_json}
      data-search-event={@search_event}
      data-search-min-length={@search_min_length}
      data-suggested-values={@suggested_values_json}
      data-testid={@testid}
      phx-hook="Combobox"
    >
      <input
        id={@field.id}
        aria-hidden="true"
        class="sr-only"
        data-role="value"
        name={@field.name}
        tabindex="-1"
        type="text"
        value={@field_value}
      />

      <label for={@display_id}>
        <span class="label">{@label}</span>
        <button
          id={@display_id}
          aria-controls={"#{@picker_id}-panel"}
          aria-expanded="false"
          class={[
            "w-full input flex items-center justify-between text-left",
            @errors != [] && "input-error"
          ]}
          data-role="trigger"
          role="combobox"
          style={"anchor-name:#{@anchor_name}"}
          type="button"
        >
          <span class="truncate" data-role="trigger-label">
            {@display_value}
          </span>
          <.icon class="size-4 opacity-60" name="hero-chevron-up-down-mini" />
        </button>
      </label>

      <div
        id={"#{@picker_id}-panel"}
        class={[
          "dropdown z-20 mt-1 w-[min(32rem,calc(100vw-2rem))] rounded",
          "bg-base-100 border border-base-content/50 p-2 shadow-lg"
        ]}
        data-role="panel"
        popover
        style={"position-anchor:#{@anchor_name}"}
      >
        <input
          aria-controls={"#{@picker_id}-options"}
          autocomplete="off"
          class="input input-sm w-full"
          data-role="search"
          placeholder={@placeholder}
          type="text"
        />

        <ul
          id={"#{@picker_id}-options"}
          class="mt-2 max-h-64 overflow-y-auto overflow-x-hidden"
          data-role="list"
          role="listbox"
        />
      </div>

      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  defp field_value(field) do
    Phoenix.HTML.Form.input_value(field.form, field.field)
  end
end
