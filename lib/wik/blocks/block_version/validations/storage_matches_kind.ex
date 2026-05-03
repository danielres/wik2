defmodule Wik.Blocks.BlockVersion.Validations.StorageMatchesKind do
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    storage_kind = changeset |> Ash.Changeset.get_attribute(:storage_kind)
    snapshot_text = changeset |> Ash.Changeset.get_attribute(:snapshot_text)
    diff_data = changeset |> Ash.Changeset.get_attribute(:diff_data)

    case storage_kind do
      :snapshot when (is_binary(snapshot_text) or is_nil(snapshot_text)) and diff_data == nil ->
        :ok

      :line_diff when is_map(diff_data) and snapshot_text == nil ->
        :ok

      :snapshot ->
        {:error,
         field: :snapshot_text, message: "snapshot versions must store snapshot text only"}

      :line_diff ->
        {:error, field: :diff_data, message: "line diff versions must store diff data only"}

      _ ->
        {:error, field: :storage_kind, message: "unsupported storage kind"}
    end
  end
end
