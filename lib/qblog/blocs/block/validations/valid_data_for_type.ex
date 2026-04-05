defmodule Qblog.Blocs.Block.Validations.ValidDataForType do
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :type) do
      :text ->
        validate_text_data(changeset)

      _ ->
        :ok
    end
  end

  defp validate_text_data(changeset) do
    text =
      changeset
      |> Ash.Changeset.get_attribute(:data)
      |> get_text()

    case text do
      nil ->
        :ok

      text when is_binary(text) ->
        :ok

      _ ->
        {:error, field: :data, message: "text blocks must store text as a string"}
    end
  end

  defp get_text(%{"text" => text}), do: text
  defp get_text(%{text: text}), do: text
  defp get_text(_), do: nil
end
