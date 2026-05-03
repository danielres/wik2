defmodule Wik.Accounts.Group.Checks.ActorIsMemberOfCurrentTenantGroup do
  use Ash.Policy.SimpleCheck

  require Ash.Query

  alias Wik.Accounts
  alias Wik.Accounts.Group.Access

  @impl true
  def describe(_opts), do: "actor is a member of the current tenant group"

  @impl true
  def match?(nil, _context, _opts), do: {:ok, false}

  def match?(actor, context, _opts) do
    {:ok, tenant} = Ash.Scope.ToOpts.get_tenant(context)
    group_id = Accounts.tenant_to_group_id(tenant)

    Access.actor_can_access_group?(actor.id, group_id)
  end
end
