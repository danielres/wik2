defmodule WikWeb.Components.TimezonePicker do
  use WikWeb, :html

  alias WikWeb.CoreComponents

  @default_suggested_values [
    "Europe/Berlin",
    "America/New_York",
    "America/Sao_Paulo",
    "Africa/Johannesburg",
    "Asia/Tokyo",
    "Australia/Sydney",
    "Pacific/Auckland"
  ]

  attr :field, Phoenix.HTML.FormField, required: true
  attr :id, :string, default: nil
  attr :label, :string, required: true
  attr :placeholder, :string, default: "Search timezones"
  attr :suggested_values, :list, default: []
  attr :testid, :string, default: nil

  def field(assigns) do
    value = field_value(assigns.field)
    options = timezone_options()
    option_by_value = Map.new(options, &{&1.value, &1})
    display_value = display_value(option_by_value, value)

    suggested_values =
      [value | assigns.suggested_values ++ @default_suggested_values]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.uniq()

    assigns =
      assigns
      |> assign(:anchor_name, "--#{assigns.id || "#{assigns.field.id}-picker"}")
      |> assign(:display_id, "#{assigns.id || assigns.field.id}-display")
      |> assign(:display_value, display_value)
      |> assign(:errors, Enum.map(assigns.field.errors, &CoreComponents.translate_error/1))
      |> assign(:options_json, Jason.encode!(options))
      |> assign(:picker_id, assigns.id || "#{assigns.field.id}-picker")
      |> assign(:suggested_values_json, Jason.encode!(suggested_values))

    ~H"""
    <div
      id={@picker_id}
      class="fieldset relative"
      data-testid={@testid}
      data-options={@options_json}
      data-suggested-values={@suggested_values_json}
      phx-hook="TimezoneCombobox"
    >
      <.input field={@field} type="hidden" />

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
          "dropdown z-20 mt-1 w-fit rounded",
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
          class="mt-2 max-h-64 overflow-y-auto"
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

  defp display_value(_option_by_value, nil), do: ""

  defp display_value(option_by_value, value) do
    case option_by_value do
      %{^value => %{label: label}} -> label
      %{} -> value
    end
  end

  defp timezone_options do
    Tzdata.canonical_zone_list()
    |> Enum.sort()
    |> Enum.map(&timezone_option/1)
  end

  defp timezone_option(value) do
    city = city_label(value)

    %{
      label: "#{city} - #{value}",
      search: "#{String.downcase(city)} #{String.downcase(value)}",
      value: value
    }
  end

  defp city_label("Etc/UTC"), do: "UTC"

  defp city_label(value) do
    value
    |> String.split("/")
    |> List.last()
    |> String.replace("_", " ")
  end
end
