defmodule Wik.Blocks.BlockPlacement.Changes.SetSpaceFromAttachable do
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Wik.Wiki.Page

  @impl true
  def change(changeset, _opts, context) do
    attachable_id = Changeset.get_attribute(changeset, :attachable_id)
    attachable_type = Changeset.get_attribute(changeset, :attachable_type)

    case attachable_to_space_id(attachable_type, attachable_id, context) do
      {:ok, space_id} ->
        Changeset.force_change_attribute(changeset, :space_id, space_id)

      {:error, message} ->
        Changeset.add_error(changeset, field: :attachable_id, message: message)
    end
  end

  defp attachable_to_space_id("page", attachable_id, context) do
    {:ok, tenant} = Ash.Scope.ToOpts.get_tenant(context)

    case Ash.get(Page, attachable_id, authorize?: false, domain: Wik.Wiki, tenant: tenant) do
      {:ok, %Page{space_id: space_id}} -> {:ok, space_id}
      _ -> {:error, "does not reference a page in the current tenant"}
    end
  end

  defp attachable_to_space_id(_attachable_type, _attachable_id, _context) do
    {:error, "has an unsupported attachable type"}
  end
end
