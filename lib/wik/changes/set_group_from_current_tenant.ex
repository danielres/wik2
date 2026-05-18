defmodule Wik.Changes.SetGroupFromCurrentTenant do
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Wik.Accounts

  @impl true
  def change(changeset, _opts, context) do
    case Ash.Scope.ToOpts.get_tenant(context) do
      {:ok, tenant} ->
        case Accounts.tenant_to_group_id(tenant) do
          nil ->
            Changeset.add_error(changeset, field: :group_id, message: "could not resolve group")

          group_id ->
            Changeset.force_change_attribute(changeset, :group_id, group_id)
        end

      _ ->
        Changeset.add_error(changeset, field: :group_id, message: "is required")
    end
  end
end
