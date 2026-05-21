defmodule Wik.Blocks.Block.Validations.ExactlyOneOwner do
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    owner_space_id = Ash.Changeset.get_attribute(changeset, :owner_space_id)
    owner_user_id = Ash.Changeset.get_attribute(changeset, :owner_user_id)

    case {owner_user_id, owner_space_id} do
      {nil, nil} ->
        {:error,
         fields: [:owner_user_id, :owner_space_id], message: "must have exactly one owner"}

      {_, nil} ->
        :ok

      {nil, _} ->
        :ok

      {_, _} ->
        {:error,
         fields: [:owner_user_id, :owner_space_id], message: "must have exactly one owner"}
    end
  end
end
