defmodule Wik.Accounts.Group.Access do
  alias Wik.Access.Grant
  alias Wik.Accounts.GroupUserRelation

  require Ash.Query

  def actor_can_access_group?(actor_id, group_id) do
    with {:ok, false} <- actor_has_owner_membership?(actor_id, group_id),
         {:ok, true} <- actor_has_membership?(actor_id, group_id, [:admin, :member]) do
      actor_has_active_grant?(actor_id, group_id)
    else
      {:ok, true} -> {:ok, true}
      {:ok, false} -> {:ok, false}
      {:error, error} -> {:error, error}
    end
  end

  def actor_can_manage_group?(actor_id, group_id) do
    with {:ok, false} <- actor_has_owner_membership?(actor_id, group_id),
         {:ok, true} <- actor_has_membership?(actor_id, group_id, [:admin]) do
      actor_has_active_grant?(actor_id, group_id)
    else
      {:ok, true} -> {:ok, true}
      {:ok, false} -> {:ok, false}
      {:error, error} -> {:error, error}
    end
  end

  defp actor_has_owner_membership?(actor_id, group_id) do
    actor_has_membership?(actor_id, group_id, [:owner])
  end

  defp actor_has_membership?(actor_id, group_id, types) do
    GroupUserRelation
    |> Ash.Query.filter(user_id == ^actor_id and group_id == ^group_id and type in ^types)
    |> Ash.exists(authorize?: false)
  end

  defp actor_has_active_grant?(actor_id, group_id) do
    Grant
    |> Ash.Query.filter(
      user_id == ^actor_id and status == :active and
        source.status == :active and source.group_id == ^group_id
    )
    |> Ash.exists(authorize?: false, domain: Wik.Access)
  end
end
