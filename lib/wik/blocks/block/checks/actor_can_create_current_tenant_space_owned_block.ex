defmodule Wik.Blocks.Block.Checks.ActorCanCreateCurrentTenantSpaceOwnedBlock do
  use Ash.Policy.SimpleCheck

  alias Wik.Accounts
  alias Wik.Accounts.Space.Checks.Access

  require Ash.Query

  @impl true
  def describe(_opts), do: "actor can create a current tenant space owned block"

  @impl true
  def match?(nil, _context, _opts), do: {:ok, false}

  def match?(actor, %{subject: subject} = context, _opts) do
    {:ok, tenant} = Ash.Scope.ToOpts.get_tenant(context)
    space_id = Accounts.tenant_to_space_id(tenant)
    owner_space_id = Ash.Subject.get_argument_or_attribute(subject, :owner_space_id)

    if owner_space_id == space_id do
      Access.actor_can_manage_space?(actor.id, space_id)
    else
      {:ok, false}
    end
  end
end
