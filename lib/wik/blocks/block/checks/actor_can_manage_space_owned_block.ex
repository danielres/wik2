defmodule Wik.Blocks.Block.Checks.ActorCanManageSpaceOwnedBlock do
  use Ash.Policy.FilterCheck

  alias Wik.Accounts.Space.Checks.Access

  require Ash.Expr

  @impl true
  def describe(_opts), do: "actor can manage the block through its owner space"

  @impl true
  def filter(nil, _context, _opts), do: false

  def filter(actor, _context, _opts) do
    Ash.Expr.expr(owner_space_id in ^Access.manageable_space_ids(actor.id))
  end
end
