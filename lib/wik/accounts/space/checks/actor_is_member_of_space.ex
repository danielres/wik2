defmodule Wik.Accounts.Space.Checks.ActorIsMemberOfSpace do
  use Ash.Policy.FilterCheck

  alias Wik.Accounts.Space.Checks.Access

  require Ash.Expr

  @impl true
  def describe(_opts), do: "actor is a member of the space"

  @impl true
  def filter(nil, _context, _opts), do: false

  def filter(actor, _context, _opts) do
    Ash.Expr.expr(id in ^Access.accessible_space_ids(actor.id))
  end
end
