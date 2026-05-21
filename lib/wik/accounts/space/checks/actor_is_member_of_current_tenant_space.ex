defmodule Wik.Accounts.Space.Checks.ActorIsMemberOfCurrentTenantSpace do
  use Ash.Policy.SimpleCheck

  require Ash.Query

  alias Wik.Accounts
  alias Wik.Accounts.Space.Access

  @impl true
  def describe(_opts), do: "actor is a member of the current tenant space"

  @impl true
  def match?(nil, _context, _opts), do: {:ok, false}

  def match?(actor, context, _opts) do
    {:ok, tenant} = Ash.Scope.ToOpts.get_tenant(context)
    space_id = Accounts.tenant_to_space_id(tenant)

    Access.actor_can_access_space?(actor.id, space_id)
  end
end
