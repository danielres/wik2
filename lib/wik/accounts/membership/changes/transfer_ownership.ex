defmodule Wik.Accounts.Membership.Changes.TransferOwnership do
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Wik.Accounts.Membership

  @impl true
  def change(changeset, _opts, _context) do
    target_membership_id = Changeset.get_argument(changeset, :target_membership_id)

    Changeset.after_action(changeset, fn _changeset, owner_membership ->
      transfer_ownership(owner_membership, target_membership_id)
    end)
  end

  defp transfer_ownership(owner_membership, target_membership_id) do
    case fetch_membership(target_membership_id) do
      {:ok, %Membership{id: target_membership_id} = _same_membership}
      when target_membership_id == owner_membership.id ->
        {:ok, owner_membership}

      {:ok, %Membership{} = target_membership} ->
        with {:ok, target_membership} <-
               validate_target_space(owner_membership, target_membership),
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
    Ash.get(Membership, target_membership_id, authorize?: false, domain: Wik.Accounts)
  end

  defp validate_target_space(current_membership, target_membership) do
    if target_membership.space_id == current_membership.space_id do
      {:ok, target_membership}
    else
      {:error,
       Ash.Error.Changes.InvalidChanges.exception(
         fields: [:target_membership_id],
         message: "target membership must belong to the same space"
       )}
    end
  end

  defp make_admin(membership) do
    membership |> Ash.update(%{type: :admin}, action: :set_type, authorize?: false)
  end

  defp make_owner(target_membership) do
    target_membership |> Ash.update(%{type: :owner}, action: :set_type, authorize?: false)
  end
end
