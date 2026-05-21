defmodule Wik.Accounts.Space.Access do
  alias Wik.Access.Grant
  alias Wik.Accounts.Membership

  require Ash.Query

  def actor_can_access_space?(actor_id, space_id) do
    with {:ok, false} <- actor_has_owner_membership?(actor_id, space_id),
         {:ok, true} <- actor_has_membership?(actor_id, space_id, [:admin, :member]) do
      actor_has_active_grant?(actor_id, space_id)
    else
      {:ok, true} -> {:ok, true}
      {:ok, false} -> {:ok, false}
      {:error, error} -> {:error, error}
    end
  end

  def actor_can_manage_space?(actor_id, space_id) do
    with {:ok, false} <- actor_has_owner_membership?(actor_id, space_id),
         {:ok, true} <- actor_has_membership?(actor_id, space_id, [:admin]) do
      actor_has_active_grant?(actor_id, space_id)
    else
      {:ok, true} -> {:ok, true}
      {:ok, false} -> {:ok, false}
      {:error, error} -> {:error, error}
    end
  end

  defp actor_has_owner_membership?(actor_id, space_id) do
    actor_has_membership?(actor_id, space_id, [:owner])
  end

  defp actor_has_membership?(actor_id, space_id, types) do
    Membership
    |> Ash.Query.filter(user_id == ^actor_id and space_id == ^space_id and type in ^types)
    |> Ash.exists(authorize?: false)
  end

  defp actor_has_active_grant?(actor_id, space_id) do
    Grant
    |> Ash.Query.filter(
      user_id == ^actor_id and status == :active and
        source.status == :active and source.space_id == ^space_id
    )
    |> Ash.exists(authorize?: false, domain: Wik.Access)
  end
end
