defmodule Wik.Blocks.Block.Checks.ActorCanCreateCurrentTenantGroupOwnedBlock do
  use Ash.Policy.SimpleCheck

  alias Wik.Accounts
  alias Wik.Accounts.Group.Access

  require Ash.Query

  @impl true
  def describe(_opts), do: "actor can create a current tenant group owned block"

  @impl true
  def match?(nil, _context, _opts), do: {:ok, false}

  def match?(actor, %{subject: subject} = context, _opts) do
    {:ok, tenant} = Ash.Scope.ToOpts.get_tenant(context)
    group_id = Accounts.tenant_to_group_id(tenant)
    owner_group_id = Ash.Subject.get_argument_or_attribute(subject, :owner_group_id)

    if owner_group_id == group_id do
      Access.actor_can_manage_group?(actor.id, group_id)
    else
      {:ok, false}
    end
  end
end
