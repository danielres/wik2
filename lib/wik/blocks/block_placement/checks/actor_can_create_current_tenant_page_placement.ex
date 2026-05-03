defmodule Wik.Blocks.BlockPlacement.Checks.ActorCanCreateCurrentTenantPagePlacement do
  use Ash.Policy.SimpleCheck

  alias Wik.Accounts
  alias Wik.Accounts.Group.Access
  alias Wik.Blocks.Block
  alias Wik.Wiki.Page

  require Ash.Query

  @impl true
  def describe(_opts), do: "actor can create a current tenant page placement"

  @impl true
  def match?(nil, _context, _opts), do: {:ok, false}

  def match?(actor, %{subject: subject} = context, _opts) do
    {:ok, tenant} = Ash.Scope.ToOpts.get_tenant(context)
    group_id = Accounts.tenant_to_group_id(tenant)
    attachable_id = Ash.Subject.get_argument_or_attribute(subject, :attachable_id)
    attachable_type = Ash.Subject.get_argument_or_attribute(subject, :attachable_type)
    block_id = Ash.Subject.get_argument_or_attribute(subject, :block_id)

    with true <- attachable_type == "page",
         {:ok, true} <- actor_manages_group?(actor.id, group_id),
         {:ok, %Page{group_id: ^group_id}} <-
           Ash.get(Page, attachable_id, authorize?: false, domain: Wik.Wiki, tenant: tenant),
         {:ok, %Block{} = block} <-
           Ash.get(Block, block_id, authorize?: false, domain: Wik.Blocks),
         true <- actor_can_place_block?(block, actor.id, group_id) do
      {:ok, true}
    else
      _ -> {:ok, false}
    end
  end

  defp actor_can_place_block?(%Block{owner_user_id: owner_user_id}, actor_id, _group_id)
       when owner_user_id == actor_id,
       do: true

  defp actor_can_place_block?(%Block{owner_group_id: owner_group_id}, _actor_id, group_id)
       when owner_group_id == group_id,
       do: true

  defp actor_can_place_block?(_block, _actor_id, _group_id), do: false

  defp actor_manages_group?(actor_id, group_id) do
    Access.actor_can_manage_group?(actor_id, group_id)
  end
end
