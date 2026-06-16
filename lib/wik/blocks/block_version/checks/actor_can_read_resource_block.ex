defmodule Wik.Blocks.BlockVersion.Checks.ActorCanReadResourceBlock do
  import Ecto.Query, only: [from: 2, subquery: 1]

  use Ash.Policy.FilterCheck

  alias Wik.Accounts.Space.Checks.Access
  alias Wik.Blocks.Block
  alias Wik.Blocks.BlockPlacement

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
        Ash.Expr.expr(block_id in ^subquery(readable_block_ids(space_ids)))
    end
  end

  defp readable_block_ids(space_ids) do
    placed_block_ids =
      from(placement in BlockPlacement,
        where: placement.space_id in ^space_ids,
        select: placement.block_id
      )

    from(block in Block,
      where: block.owner_space_id in ^space_ids or block.id in subquery(placed_block_ids),
      select: block.id,
      distinct: true
    )
  end
end
