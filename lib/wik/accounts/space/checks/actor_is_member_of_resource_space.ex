defmodule Wik.Accounts.Space.Checks.ActorIsMemberOfResourceSpace do
  use Ash.Policy.FilterCheck

  alias Wik.Accounts.Space.Checks.Access

  require Ash.Expr

  @impl true
  def describe(_opts), do: "actor is a member of the current resource space"

  @impl true
  def filter(nil, _context, _opts), do: false

  def filter(actor, %{resource: resource}, _opts) do
    %{source_attribute: source_attribute} = Ash.Resource.Info.relationship(resource, :space)

    Ash.Expr.expr(^Ash.Expr.ref(source_attribute) in ^Access.accessible_space_ids(actor.id))
  end
end
