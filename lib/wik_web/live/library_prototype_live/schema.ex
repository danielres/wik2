defmodule WikWeb.LibraryPrototypeLive.Schema do
  @moduledoc false

  @format "wik-library-type"
  @version 1

  @field_types [
    {:text, "Text"},
    {:rich_text, "Rich text"},
    {:number, "Number"},
    {:boolean, "Checkbox"},
    {:select, "Select"},
    {:date, "Date"},
    {:url, "URL"},
    {:email, "Email"},
    {:phone, "Phone"},
    {:location, "Location"},
    {:media, "Media"}
  ]

  @type_by_name Map.new([{:title, "Title"} | @field_types], fn {type, _label} ->
                  {Atom.to_string(type), type}
                end)

  def field_type_options, do: Enum.map(@field_types, fn {type, label} -> {label, type} end)

  def field_type_label(type) do
    [{:title, "Title"} | @field_types]
    |> Enum.find_value("Unknown", fn
      {^type, label} -> label
      _field_type -> nil
    end)
  end

  def built_in_templates do
    [
      template(
        "place",
        "Place",
        "Landmarks, venues, and other useful locations.",
        "hero-map-pin-micro",
        [
          title_field("name", "Name"),
          field("location", "Location", :location),
          field("website", "Website", :url),
          field("phone", "Phone", :phone),
          field("notes", "Notes", :rich_text)
        ]
      ),
      template(
        "contact",
        "Contact",
        "Professionals, organizations, and other useful contacts.",
        "hero-identification-micro",
        [
          title_field("name", "Name"),
          field("organization", "Organization", :text),
          field("role", "Role or title", :text),
          field("phone", "Phone", :phone),
          field("email", "Email", :email),
          field("website", "Website", :url),
          field("notes", "Notes", :rich_text)
        ]
      ),
      template(
        "external-media",
        "External media",
        "Videos, tracks, mixes, and other external media.",
        "hero-play-circle-micro",
        [
          field("media", "Media", :media, required?: true),
          title_field("title", "Title"),
          field("creator", "Creator", :text),
          field("duration", "Duration", :text),
          field("notes", "Notes", :rich_text)
        ]
      ),
      template(
        "recipe",
        "Recipe",
        "Recipes, dishes, and other cooking references.",
        "hero-book-open-micro",
        [
          title_field("name", "Name"),
          field("duration", "Duration", :select,
            options: ["0-5 min", "5-10 min", "10-20 min", "20-30 min", "30-60 min", "60+ min"]
          ),
          field("ingredients", "Ingredients", :rich_text),
          field("instructions", "Instructions", :rich_text),
          field("notes", "Notes", :rich_text)
        ]
      ),
      template(
        "custom",
        "Custom",
        "Start with a name and build exactly the schema you need.",
        "hero-adjustments-horizontal-micro",
        [title_field("name", "Name")]
      )
    ]
  end

  def find_template(templates, id), do: Enum.find(templates, &(&1.id == id))

  def instantiate_template(template) do
    %{
      description: template.description,
      fields: Enum.map(template.fields, &Map.put(&1, :id, unique_id("field"))),
      name: template.name
    }
  end

  def export(type) do
    blueprint = %{
      "type" => %{
        "description" => type.description,
        "name" => type.name
      },
      "fields" => Enum.map(type.fields, &export_field/1),
      "format" => @format,
      "version" => @version
    }

    Jason.encode!(blueprint, pretty: true)
  end

  def import(json) when is_binary(json) do
    with {:ok, blueprint} <- Jason.decode(json),
         :ok <- validate_blueprint_header(blueprint),
         {:ok, type} <- import_type(blueprint["type"]),
         {:ok, fields} <- import_fields(blueprint["fields"]) do
      {:ok, Map.put(type, :fields, fields)}
    else
      {:error, %Jason.DecodeError{}} -> {:error, "Paste valid JSON to import a schema."}
      {:error, message} when is_binary(message) -> {:error, message}
      _error -> {:error, "This schema could not be imported."}
    end
  end

  def import(_json), do: {:error, "Paste valid JSON to import a schema."}

  def type_attrs(params) do
    name = Map.get(params, "name", "")
    description = Map.get(params, "description", "")

    cond do
      not is_binary(name) or not is_binary(description) ->
        {:error, "The type metadata is invalid."}

      String.trim(name) == "" ->
        {:error, "A type name is required."}

      true ->
        {:ok, %{description: String.trim(description), name: String.trim(name)}}
    end
  end

  def field_attrs(params, fields, existing_field \\ nil) do
    label = params |> Map.get("label", "") |> String.trim()

    type =
      params
      |> Map.get("type", (existing_field && existing_field.type) || "text")
      |> param_to_type()

    required? =
      Map.get(
        params,
        "required",
        (existing_field && to_string(existing_field.required?)) || "false"
      ) ==
        "true"

    options = params |> Map.get("options", "") |> options_from_param()

    key =
      case existing_field do
        nil -> unique_field_key(fields, label)
        field -> field.key
      end

    cond do
      label == "" ->
        {:error, "A field label is required."}

      type == nil ->
        {:error, "Choose a supported field type."}

      type == :select and options == [] ->
        {:error, "Select fields need at least one option."}

      true ->
        {:ok,
         %{
           id: (existing_field && existing_field.id) || unique_id("field"),
           key: key,
           label: label,
           options: if(type == :select, do: options, else: []),
           required?: required?,
           type: type
         }}
    end
  end

  def entry_values(fields, params) do
    {values, errors} =
      Enum.reduce(fields, {%{}, []}, fn field, {values, errors} ->
        value = Map.get(params, field.key, "")

        case normalize_entry_value(field, value) do
          {:ok, normalized} -> {Map.put(values, field.key, normalized), errors}
          {:error, message} -> {values, errors ++ ["#{field.label}: #{message}"]}
        end
      end)

    case errors do
      [] -> {:ok, values}
      errors -> {:error, errors}
    end
  end

  def blank_value?(nil), do: true
  def blank_value?(""), do: true
  def blank_value?(_value), do: false

  def field_value(entry, field), do: Map.get(entry.values, field.key)

  defp template(id, name, description, icon, fields) do
    %{description: description, fields: fields, icon: icon, id: id, name: name}
  end

  defp title_field(key, label), do: field(key, label, :title, required?: true)

  defp field(key, label, type, opts \\ []) do
    %{
      id: nil,
      key: key,
      label: label,
      options: Keyword.get(opts, :options, []),
      required?: Keyword.get(opts, :required?, false),
      type: type
    }
  end

  defp export_field(field) do
    exported_field = %{
      "key" => field.key,
      "label" => field.label,
      "required" => field.required?,
      "type" => Atom.to_string(field.type)
    }

    if field.type == :select do
      Map.put(exported_field, "options", field.options)
    else
      exported_field
    end
  end

  defp validate_blueprint_header(%{"format" => @format, "version" => @version}), do: :ok

  defp validate_blueprint_header(%{"format" => @format, "version" => version}) do
    {:error, "Schema version #{inspect(version)} is not supported."}
  end

  defp validate_blueprint_header(_blueprint) do
    {:error, "This is not a Wik Library type."}
  end

  defp import_type(%{"name" => name} = type) when is_binary(name) do
    type_attrs(%{
      "description" => Map.get(type, "description", ""),
      "name" => name
    })
  end

  defp import_type(_type), do: {:error, "The type metadata is invalid."}

  defp import_fields(fields) when is_list(fields) do
    with {:ok, imported_fields} <- import_field_list(fields),
         :ok <- validate_imported_fields(imported_fields) do
      {:ok, imported_fields}
    end
  end

  defp import_fields(_fields), do: {:error, "The schema fields must be a list."}

  defp import_field_list(fields) do
    Enum.reduce_while(fields, {:ok, []}, fn field, {:ok, imported_fields} ->
      case import_field(field) do
        {:ok, imported_field} -> {:cont, {:ok, imported_fields ++ [imported_field]}}
        {:error, message} -> {:halt, {:error, message}}
      end
    end)
  end

  defp import_field(
         %{
           "key" => key,
           "label" => label,
           "type" => type_name
         } = field
       )
       when is_binary(key) and is_binary(label) and is_binary(type_name) do
    type = Map.get(@type_by_name, type_name)
    options = Map.get(field, "options", [])
    required? = Map.get(field, "required", false)

    cond do
      not valid_key?(key) ->
        {:error, "Field key #{inspect(key)} is invalid."}

      String.trim(label) == "" ->
        {:error, "Every field needs a label."}

      type == nil ->
        {:error, "Field type #{inspect(type_name)} is not supported."}

      not is_boolean(required?) ->
        {:error, "Field #{inspect(key)} has an invalid required flag."}

      type == :select and not valid_options?(options) ->
        {:error, "Select field #{inspect(key)} needs unique text options."}

      type != :select and options not in [[], nil] ->
        {:error, "Only select fields may define options."}

      true ->
        {:ok,
         %{
           id: unique_id("field"),
           key: key,
           label: String.trim(label),
           options: if(type == :select, do: options, else: []),
           required?: if(type == :title, do: true, else: required?),
           type: type
         }}
    end
  end

  defp import_field(_field), do: {:error, "Every field needs a key, label, and type."}

  defp validate_imported_fields(fields) when is_list(fields) and fields != [] do
    keys = Enum.map(fields, & &1.key)

    cond do
      Enum.count(fields, &(&1.type == :title)) != 1 ->
        {:error, "A schema must contain exactly one title field."}

      Enum.uniq(keys) != keys ->
        {:error, "Field keys must be unique."}

      true ->
        :ok
    end
  end

  defp validate_imported_fields(_fields), do: {:error, "A schema needs at least one field."}

  defp normalize_entry_value(field, value) do
    value = normalize_raw_value(field.type, value)

    cond do
      field.required? and blank_value?(value) ->
        {:error, "is required"}

      blank_value?(value) ->
        {:ok, ""}

      field.type == :number ->
        normalize_number(value)

      field.type == :date ->
        normalize_date(value)

      field.type in [:url, :media] ->
        normalize_url(value)

      field.type == :email and not Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, value) ->
        {:error, "enter a valid email address"}

      field.type == :select and value not in field.options ->
        {:error, "choose a valid option"}

      true ->
        {:ok, value}
    end
  end

  defp normalize_raw_value(:boolean, value), do: value in [true, "true", "on", "1"]
  defp normalize_raw_value(:rich_text, value) when is_binary(value), do: value
  defp normalize_raw_value(_type, value) when is_binary(value), do: String.trim(value)
  defp normalize_raw_value(_type, nil), do: ""
  defp normalize_raw_value(_type, value), do: value

  defp normalize_number(value) when is_number(value), do: {:ok, value}

  defp normalize_number(value) do
    case Float.parse(value) do
      {number, ""} -> {:ok, number}
      _result -> {:error, "enter a valid number"}
    end
  end

  defp normalize_date(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, Date.to_iso8601(date)}
      {:error, _reason} -> {:error, "enter a valid date"}
    end
  end

  defp normalize_url(value) do
    case URI.parse(value) do
      %URI{host: host, scheme: scheme} when is_binary(host) and scheme in ["http", "https"] ->
        {:ok, value}

      _uri ->
        {:error, "enter a complete http or https URL"}
    end
  end

  defp param_to_type(type) when is_atom(type) do
    if type in [:title | Keyword.keys(@field_types)], do: type
  end

  defp param_to_type(type) when is_binary(type), do: Map.get(@type_by_name, type)
  defp param_to_type(_type), do: nil

  defp options_from_param(options) when is_binary(options) do
    options
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp options_from_param(_options), do: []

  defp valid_options?(options) when is_list(options) do
    options != [] and Enum.all?(options, &(is_binary(&1) and String.trim(&1) != "")) and
      Enum.uniq(options) == options
  end

  defp valid_options?(_options), do: false

  defp valid_key?(key), do: Regex.match?(~r/^[a-z][a-z0-9_]*$/, key)

  defp unique_field_key(fields, label) do
    base =
      label
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/u, "_")
      |> String.trim("_")
      |> case do
        "" -> "field"
        key -> if Regex.match?(~r/^[a-z]/, key), do: key, else: "field_#{key}"
      end

    used_keys = MapSet.new(fields, & &1.key)

    Stream.iterate(1, &(&1 + 1))
    |> Enum.find_value(fn
      1 -> if not MapSet.member?(used_keys, base), do: base
      suffix -> if not MapSet.member?(used_keys, "#{base}_#{suffix}"), do: "#{base}_#{suffix}"
    end)
  end

  defp unique_id(prefix) do
    "#{prefix}-#{System.unique_integer([:monotonic, :positive])}"
  end
end
