defmodule Qblog.Blocks.BlockPlacement.Changes.SetGroupFromAttachable do
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Qblog.Wiki.Page

  @impl true
  def change(changeset, _opts, context) do
    attachable_id = Changeset.get_attribute(changeset, :attachable_id)
    attachable_type = Changeset.get_attribute(changeset, :attachable_type)

    case attachable_to_group_id(attachable_type, attachable_id, context) do
      {:ok, group_id} ->
        Changeset.force_change_attribute(changeset, :group_id, group_id)

      {:error, message} ->
        Changeset.add_error(changeset, field: :attachable_id, message: message)
    end
  end

  defp attachable_to_group_id("page", attachable_id, context) do
    {:ok, tenant} = Ash.Scope.ToOpts.get_tenant(context)

    case Ash.get(Page, attachable_id, authorize?: false, domain: Qblog.Wiki, tenant: tenant) do
      {:ok, %Page{group_id: group_id}} -> {:ok, group_id}
      _ -> {:error, "does not reference a page in the current tenant"}
    end
  end

  defp attachable_to_group_id(_attachable_type, _attachable_id, _context) do
    {:error, "has an unsupported attachable type"}
  end
end
