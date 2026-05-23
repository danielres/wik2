defmodule Wik.Accounts.Space.Checks.ActorCanManageSpace do
  use Ash.Policy.FilterCheck

  alias Wik.Accounts.Space.Checks.Access

  require Ash.Expr

  @impl true
  def describe(_opts), do: "actor can manage the space"

  @impl true
  def filter(nil, _context, _opts), do: false

  def filter(actor, _context, _opts) do
    Ash.Expr.expr(id in ^Access.manageable_space_ids(actor.id))
  end
end
