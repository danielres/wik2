defmodule Wik.Blocks.BlockPlacement.Checks.ActorCanCreateCurrentTenantPagePlacement do
  use Ash.Policy.SimpleCheck

  alias Wik.Accounts
  alias Wik.Accounts.Space.Checks.Access
  alias Wik.Blocks.Block
  alias Wik.Wiki.Page

  require Ash.Query

  @impl true
  def describe(_opts), do: "actor can create a current tenant page placement"

  @impl true
  def match?(nil, _context, _opts), do: {:ok, false}

  def match?(actor, %{subject: subject} = context, _opts) do
    {:ok, tenant} = Ash.Scope.ToOpts.get_tenant(context)
    space_id = Accounts.tenant_to_space_id(tenant)
    attachable_id = Ash.Subject.get_argument_or_attribute(subject, :attachable_id)
    attachable_type = Ash.Subject.get_argument_or_attribute(subject, :attachable_type)
    block_id = Ash.Subject.get_argument_or_attribute(subject, :block_id)

    with {:ok, true} <-
           actor_can_create_attachable_placement?(
             attachable_type,
             attachable_id,
             actor.id,
             space_id,
             tenant
           ),
         {:ok, %Block{} = block} <-
           Ash.get(Block, block_id, authorize?: false, domain: Wik.Blocks),
         true <- actor_can_place_block?(block, actor.id, space_id) do
      {:ok, true}
    else
      _ -> {:ok, false}
    end
  end

  defp actor_can_create_attachable_placement?("page", attachable_id, actor_id, space_id, tenant) do
    with {:ok, true} <- actor_manages_space?(actor_id, space_id),
         {:ok, %Page{space_id: ^space_id}} <-
           Ash.get(Page, attachable_id, authorize?: false, domain: Wik.Wiki, tenant: tenant) do
      {:ok, true}
    else
      _ -> {:ok, false}
    end
  end

  defp actor_can_create_attachable_placement?(
         _type,
         _attachable_id,
         _actor_id,
         _space_id,
         _tenant
       ),
       do: {:ok, false}

  defp actor_can_place_block?(%Block{owner_user_id: owner_user_id}, actor_id, _space_id)
       when owner_user_id == actor_id,
       do: true

  defp actor_can_place_block?(%Block{owner_space_id: owner_space_id}, _actor_id, space_id)
       when owner_space_id == space_id,
       do: true

  defp actor_can_place_block?(_block, _actor_id, _space_id), do: false

  defp actor_manages_space?(actor_id, space_id) do
    Access.actor_can_manage_space?(actor_id, space_id)
  end
end
