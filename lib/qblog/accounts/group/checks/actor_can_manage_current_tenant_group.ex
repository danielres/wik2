defmodule Qblog.Accounts.Group.Checks.ActorCanManageCurrentTenantGroup do
  use Ash.Policy.SimpleCheck

  require Ash.Query

  alias Qblog.Accounts
  alias Qblog.Accounts.Group.Access

  @impl true
  def describe(_opts), do: "actor can manage the current tenant group"

  @impl true
  def match?(nil, _context, _opts), do: {:ok, false}

  def match?(actor, context, _opts) do
    {:ok, tenant} = Ash.Scope.ToOpts.get_tenant(context)
    group_id = Accounts.tenant_to_group_id(tenant)

    Access.actor_can_manage_group?(actor.id, group_id)
  end
end
