defmodule Wik.Accounts.Group.Checks.ActorCanManageResourceGroup do
  use Ash.Policy.FilterCheck

  @impl true
  def describe(_opts), do: "actor can manage the current resource group"

  @impl true
  def filter(nil, _context, _opts), do: false

  def filter(_actor, _context, _opts) do
    expr(
      exists(group.memberships, user_id == ^actor(:id) and type == :owner) or
        (exists(group.memberships, user_id == ^actor(:id) and type == :admin) and
           exists(
             group.access_sources,
             status == :active and
               exists(grants, user_id == ^actor(:id) and status == :active)
           ))
    )
  end
end
