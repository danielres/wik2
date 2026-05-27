defmodule Wik.Blocks.Block.Checks.ActorCanReadPlacedBlock do
  import Ecto.Query, only: [from: 2]

  use Ash.Policy.FilterCheck

  alias Wik.Accounts.Space.Checks.Access
  alias Wik.Blocks.BlockPlacement
  alias Wik.Repo

  require Ash.Expr

  @impl true
  def describe(_opts), do: "actor can read the block through a placement in a readable space"

  @impl true
  def filter(nil, _context, _opts), do: false

  def filter(actor, _context, _opts) do
    Ash.Expr.expr(id in ^placed_block_ids(Access.accessible_space_ids(actor.id)))
  end

  defp placed_block_ids([]), do: []

  defp placed_block_ids(space_ids) do
    from(placement in BlockPlacement,
      where: placement.space_id in ^space_ids,
      select: placement.block_id,
      distinct: true
    )
    |> Repo.all()
  end
end
