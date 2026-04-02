defmodule Qblog.Changes.GroupUserRelationTransferOwnership do
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Qblog.Accounts.GroupUserRelation

  @impl true
  def change(changeset, _opts, _context) do
    target_membership_id = Changeset.get_argument(changeset, :target_membership_id)

    Changeset.after_action(changeset, fn _changeset, owner_membership ->
      transfer_ownership(owner_membership, target_membership_id)
    end)
  end

  defp transfer_ownership(owner_membership, target_membership_id) do
    case fetch_membership(target_membership_id) do
      {:ok, %GroupUserRelation{id: target_membership_id} = _same_membership}
      when target_membership_id == owner_membership.id ->
        {:ok, owner_membership}

      {:ok, %GroupUserRelation{} = target_membership} ->
        with {:ok, target_membership} <-
               validate_target_group(owner_membership, target_membership),
             {:ok, updated_membership} <- make_admin(owner_membership),
             {:ok, _target_membership} <- make_owner(target_membership) do
          {:ok, updated_membership}
        end

      {:ok, nil} ->
        {:error,
         Ash.Error.Changes.InvalidChanges.exception(message: "target membership not found")}

      {:error, error} ->
        {:error, error}
    end
  end

  defp fetch_membership(target_membership_id) do
    Ash.get(GroupUserRelation, target_membership_id, authorize?: false, domain: Qblog.Accounts)
  end

  defp validate_target_group(current_membership, target_membership) do
    if target_membership.group_id == current_membership.group_id do
      {:ok, target_membership}
    else
      {:error,
       Ash.Error.Changes.InvalidChanges.exception(
         fields: [:target_membership_id],
         message: "target membership must belong to the same group"
       )}
    end
  end

  defp make_admin(membership) do
    membership |> Ash.update(%{type: :admin}, action: :update, authorize?: false)
  end

  defp make_owner(target_membership) do
    target_membership |> Ash.update(%{type: :owner}, action: :update, authorize?: false)
  end
end
