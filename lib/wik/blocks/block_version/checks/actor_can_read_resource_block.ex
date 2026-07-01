defmodule Wik.Blocks.BlockVersion.Checks.ActorCanReadResourceBlock do
  import Ecto.Query, only: [from: 2]

  use Ash.Policy.FilterCheck

  alias Wik.Accounts.Space.Checks.Access
  alias Wik.Blocks.Block
  alias Wik.Blocks.BlockPlacement
  alias Wik.Repo

  require Ash.Expr

  @impl true
  def describe(_opts), do: "actor can read the current resource block"

  @impl true
  def filter(nil, _context, _opts), do: false

  def filter(actor, _context, _opts) do
    case Access.accessible_space_ids(actor.id) do
      [] ->
        false

      space_ids ->
        Ash.Expr.expr(block_id in ^readable_block_ids(space_ids))
    end
  end

  defp readable_block_ids(space_ids) do
    from(block in Block,
      left_join: placement in BlockPlacement,
      on: placement.block_id == block.id and placement.space_id in ^space_ids,
      where: block.owner_space_id in ^space_ids or not is_nil(placement.id),
      select: block.id,
      distinct: true
    )
    |> Repo.all()
  end
end
