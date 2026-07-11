defmodule Wik.Tags.Tagging.Changes.NormalizeFields do
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Wik.Tags.Dimensions

  @impl true
  def change(changeset, _opts, _context) do
    taggable_type = Changeset.get_argument_or_attribute(changeset, :taggable_type)

    with {:ok, dimensions} <-
           normalize_dimensions(
             Changeset.get_argument_or_attribute(changeset, :dimensions),
             taggable_type
           ) do
      changeset
      |> Changeset.force_change_attribute(:dimensions, dimensions)
      |> Changeset.force_change_attribute(
        :description,
        blank_to_nil(Changeset.get_argument_or_attribute(changeset, :description))
      )
    else
      {:error, field, message} ->
        Changeset.add_error(changeset, field: field, message: message)
    end
  end

  defp normalize_dimensions(nil, _taggable_type), do: {:error, :dimensions, "is required"}

  defp normalize_dimensions(dimensions, _taggable_type) when not is_map(dimensions),
    do: {:error, :dimensions, "must be a map"}

  defp normalize_dimensions(dimensions, taggable_type) when is_binary(taggable_type) do
    dimensions_by_key =
      taggable_type
      |> Dimensions.all_for()
      |> Map.new(&{&1.key, &1})

    normalized =
      Enum.reduce_while(dimensions, %{}, fn {key, value}, acc ->
        definition = dimensions_by_key[normalize_dimension_key(key)]

        cond do
          is_nil(definition) ->
            {:halt, {:error, :dimensions, "contains an unsupported dimension key"}}

          not is_integer(value) or value not in 0..definition.max ->
            {:halt, {:error, :dimensions, invalid_level_message(definition)}}

          value == 0 ->
            {:cont, acc}

          true ->
            {:cont, Map.put(acc, definition.key, value)}
        end
      end)

    case normalized do
      {:error, _field, _message} = error ->
        error

      dimensions when map_size(dimensions) == 0 ->
        {:error, :dimensions, "must include at least one non-zero dimension"}

      dimensions ->
        {:ok, dimensions}
    end
  end

  defp normalize_dimensions(_dimensions, _taggable_type),
    do: {:error, :taggable_type, "is required"}

  defp normalize_dimension_key(key) when is_binary(key), do: key
  defp normalize_dimension_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_dimension_key(_key), do: "__unsupported__"

  defp invalid_level_message(definition),
    do: "#{definition.label} must be an integer between 0 and #{definition.max}"

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) do
    case value |> to_string() |> String.trim() do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
