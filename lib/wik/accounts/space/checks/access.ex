defmodule Wik.Accounts.Space.Checks.Access do
  import Ecto.Query, only: [from: 2]

  alias Wik.Repo

  @doc """
  Returns the ids of spaces the actor can access.

  Accessible spaces include:
  - spaces where the actor is an owner
  - spaces where the actor is an admin or member and also has an active grant
  """
  def accessible_space_ids(actor_id) do
    owner_membership_space_ids = membership_space_ids(actor_id, [:owner])
    member_membership_space_ids = membership_space_ids(actor_id, [:admin, :member])
    grant_space_ids = active_grant_space_ids(actor_id, member_membership_space_ids)

    (owner_membership_space_ids ++ grant_space_ids)
    |> Enum.uniq()
  end

  @doc """
  Returns the ids of spaces the actor can manage.

  Manageable spaces include:
  - spaces where the actor is an owner
  - spaces where the actor is an admin and also has an active grant
  """
  def manageable_space_ids(actor_id) do
    owner_membership_space_ids = membership_space_ids(actor_id, [:owner])
    admin_membership_space_ids = membership_space_ids(actor_id, [:admin])
    grant_space_ids = active_grant_space_ids(actor_id, admin_membership_space_ids)

    (owner_membership_space_ids ++ grant_space_ids)
    |> Enum.uniq()
  end

  @doc """
  Returns whether the actor can access the given space.

  Actors can access a space when they are:
  - an owner of the space
  - an admin or member of the space with an active grant
  """
  def actor_can_access_space?(actor_id, space_id) do
    with {:ok, false} <- actor_has_membership?(actor_id, space_id, [:owner]),
         {:ok, true} <- actor_has_membership?(actor_id, space_id, [:admin, :member]) do
      actor_has_active_grant?(actor_id, space_id)
    else
      {:ok, true} -> {:ok, true}
      {:ok, false} -> {:ok, false}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Returns whether the actor can manage the given space.

  Actors can manage a space when they are:
  - an owner of the space
  - an admin of the space with an active grant
  """
  def actor_can_manage_space?(actor_id, space_id) do
    with {:ok, false} <- actor_has_membership?(actor_id, space_id, [:owner]),
         {:ok, true} <- actor_has_membership?(actor_id, space_id, [:admin]) do
      actor_has_active_grant?(actor_id, space_id)
    else
      {:ok, true} -> {:ok, true}
      {:ok, false} -> {:ok, false}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Returns the ids of spaces where the actor has a membership of one of the given types.
  """
  def membership_space_ids(actor_id, types) do
    membership_types = Enum.map(types, &Atom.to_string/1)

    from(membership in "memberships",
      where:
        membership.user_id == type(^actor_id, Ecto.UUID) and
          membership.type in ^membership_types,
      select: membership.space_id
    )
    |> Repo.all()
    |> Enum.map(&normalize_uuid/1)
  end

  defp actor_has_membership?(actor_id, space_id, types) do
    membership_types = Enum.map(types, &Atom.to_string/1)

    query =
      from(membership in "memberships",
        where:
          membership.user_id == type(^actor_id, Ecto.UUID) and
            membership.space_id == type(^space_id, Ecto.UUID) and
            membership.type in ^membership_types
      )

    {:ok, Repo.exists?(query)}
  end

  defp active_grant_space_ids(_actor_id, []), do: []

  defp active_grant_space_ids(actor_id, space_ids) do
    from(grant in "access_grants",
      join: source in "access_sources",
      on: source.id == grant.source_id,
      where:
        grant.user_id == type(^actor_id, Ecto.UUID) and grant.status == "active" and
          source.status == "active" and
          source.space_id in type(^space_ids, {:array, Ecto.UUID}),
      select: source.space_id,
      distinct: true
    )
    |> Repo.all()
    |> Enum.map(&normalize_uuid/1)
  end

  defp actor_has_active_grant?(actor_id, space_id) do
    query =
      from(grant in "access_grants",
        join: source in "access_sources",
        on: source.id == grant.source_id,
        where:
          grant.user_id == type(^actor_id, Ecto.UUID) and grant.status == "active" and
            source.status == "active" and
            source.space_id == type(^space_id, Ecto.UUID)
      )

    {:ok, Repo.exists?(query)}
  end

  defp normalize_uuid(<<_::128>> = uuid), do: Ecto.UUID.load!(uuid)
  defp normalize_uuid(uuid), do: uuid
end
