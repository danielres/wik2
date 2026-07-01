defmodule Wik.Tags.Tag.Validations.PrimaryBlock do
  use Ash.Resource.Validation

  alias Ash.Query
  alias Wik.Blocks.Block

  require Ash.Query

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    primary_block_id = Ash.Changeset.get_attribute(changeset, :primary_block_id)
    space_id = Ash.Changeset.get_attribute(changeset, :space_id) || changeset.data.space_id

    case {primary_block_id, space_id} do
      {nil, _space_id} ->
        :ok

      {_primary_block_id, nil} ->
        {:error, field: :primary_block_id, message: "must belong to the tag space"}

      {primary_block_id, space_id} ->
        validate_primary_block(primary_block_id, space_id)
    end
  end

  defp validate_primary_block(primary_block_id, space_id) do
    Block
    |> Query.filter(id == ^primary_block_id)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %Block{type: :markdown, owner_space_id: ^space_id}} ->
        :ok

      {:ok, %Block{}} ->
        {:error,
         field: :primary_block_id, message: "must be a markdown block owned by the tag space"}

      {:ok, nil} ->
        {:error, field: :primary_block_id, message: "does not exist"}

      {:error, error} ->
        {:error, error}
    end
  end
end
