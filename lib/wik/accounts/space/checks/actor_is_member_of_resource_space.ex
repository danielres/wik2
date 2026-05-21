defmodule Wik.Accounts.Space.Checks.ActorIsMemberOfResourceSpace do
  use Ash.Policy.FilterCheck

  @impl true
  def describe(_opts), do: "actor is a member of the current resource space"

  @impl true
  def filter(nil, _context, _opts), do: false

  def filter(_actor, _context, _opts) do
    expr(
      exists(space.memberships, user_id == ^actor(:id) and type == :owner) or
        (exists(space.memberships, user_id == ^actor(:id) and type in [:admin, :member]) and
           exists(
             space.access_sources,
             status == :active and
               exists(grants, user_id == ^actor(:id) and status == :active)
           ))
    )
  end
end
