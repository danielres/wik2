# TODO: add tests
# TODO: rename Blocs to Blocks

defmodule Qblog.Blocs do
  use Ash.Domain,
    otp_app: :qblog,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  alias Qblog.Blocs.Block

  admin do
    show? true
  end

  resources do
    resource Qblog.Blocs.Block
    resource Qblog.Blocs.BlockPlacement
  end

  def create_group_owned_block(%{id: group_id}, block_attrs, opts) do
    scope = Keyword.fetch!(opts, :scope)

    block_attrs
    |> Map.delete(:owner_user_id)
    |> Map.put(:owner_group_id, group_id)
    |> then(&Ash.create(Block, &1, scope: scope))
  end

  def create_user_owned_block(block_attrs, opts) do
    scope = Keyword.fetch!(opts, :scope)

    block_attrs
    |> Map.delete(:owner_group_id)
    |> Map.put(:owner_user_id, scope.actor.id)
    |> then(&Ash.create(Block, &1, scope: scope))
  end
end
