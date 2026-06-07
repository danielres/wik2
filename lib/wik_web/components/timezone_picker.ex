defmodule WikWeb.Components.TimezonePicker do
  use WikWeb, :html

  alias WikWeb.Components.Combobox
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
  @timezone_data_key {__MODULE__, :timezone_data}

  attr :field, Phoenix.HTML.FormField, required: true
  attr :id, :string, default: nil
  attr :label, :string, required: true
  attr :placeholder, :string, default: "Search timezones"
  attr :suggested_values, :list, default: []
  attr :testid, :string, default: nil

  def field(assigns) do
    value = field_value(assigns.field)
    %{option_by_value: option_by_value, options_json: options_json} = timezone_data()
    display_value = display_value(option_by_value, value)

    suggested_values =
      [value | assigns.suggested_values ++ @default_suggested_values]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.uniq()

    assigns =
      assigns
      |> assign(:display_value, display_value)
      |> assign(:errors, CoreComponents.field_errors(assigns.field))
      |> assign(:options_json, options_json)
      |> assign(:suggested_values_json, Jason.encode!(suggested_values))

    ~H"""
    <Combobox.field
      display_value={@display_value}
      empty_display="Set custom timezone"
      empty_message="No matching timezone"
      errors={@errors}
      field={@field}
      id={@id}
      label={@label}
      options_json={@options_json}
      placeholder={@placeholder}
      suggested_values_json={@suggested_values_json}
      testid={@testid}
    />
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

  defp timezone_data do
    case :persistent_term.get(@timezone_data_key, nil) do
      nil ->
        data = build_timezone_data()
        :persistent_term.put(@timezone_data_key, data)
        data

      data ->
        data
    end
  end

  defp build_timezone_data do
    options =
      Tzdata.canonical_zone_list()
      |> Enum.sort()
      |> Enum.map(fn value ->
        city =
          case value do
            "Etc/UTC" ->
              "UTC"

            _ ->
              value
              |> String.split("/")
              |> List.last()
              |> String.replace("_", " ")
          end

        %{
          label: "#{city} - #{value}",
          search: "#{String.downcase(city)} #{String.downcase(value)}",
          value: value
        }
      end)

    %{
      option_by_value: Map.new(options, &{&1.value, &1}),
      options_json: Jason.encode!(options)
    }
  end
end
