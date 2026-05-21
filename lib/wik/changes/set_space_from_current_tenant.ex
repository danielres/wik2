defmodule Wik.Changes.SetSpaceFromCurrentTenant do
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Wik.Accounts

  @impl true
  def change(changeset, _opts, context) do
    case Ash.Scope.ToOpts.get_tenant(context) do
      {:ok, tenant} ->
        case Accounts.tenant_to_space_id(tenant) do
          nil ->
            Changeset.add_error(changeset, field: :space_id, message: "could not resolve space")

          space_id ->
            Changeset.force_change_attribute(changeset, :space_id, space_id)
        end

      _ ->
        Changeset.add_error(changeset, field: :space_id, message: "is required")
    end
  end
end
