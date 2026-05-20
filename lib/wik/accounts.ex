defmodule Wik.Accounts do
  use Ash.Domain,
    otp_app: :wik,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  admin do
    show? true
  end

  resources do
    resource Wik.Accounts.Token
    resource Wik.Accounts.User
    resource Wik.Accounts.Profile

    resource Wik.Accounts.Group do
      define :get_group_by_slug, action: :read, get_by_identity: :unique_slug

      # TODO: filter by actor
      define :list_groups,
        action: :read,
        args: [],
        default_options: [
          query: [sort: [inserted_at: :desc]],
          load: [:author]
        ]
    end

    resource Wik.Accounts.GroupUserRelation
  end

  require Ash.Query

  alias Wik.Accounts.Group
  alias Wik.Accounts.GroupUserRelation
  alias Wik.Accounts.User

  def list_owned_groups(%User{id: user_id}) do
    Group
    |> Ash.Query.filter(exists(memberships, user_id == ^user_id and type == :owner))
    |> Ash.Query.sort(name: :asc)
    |> Ash.read(authorize?: false, domain: __MODULE__)
  end

  def group_slug_to_id(group_slug) do
    case get_group_by_slug(group_slug, authorize?: false) do
      {:ok, %{id: id}} -> id
      {:error, _reason} -> nil
    end
  end

  def tenant_to_group_id(%{id: group_id}), do: group_id
  def tenant_to_group_id(group_slug) when is_binary(group_slug), do: group_slug_to_id(group_slug)
  def tenant_to_group_id(_), do: nil

  def get_membership(%Group{id: group_id}, %User{id: user_id}),
    do: get_membership(group_id, user_id)

  def get_membership(group_id, user_id) when is_binary(group_id) and is_binary(user_id) do
    GroupUserRelation
    |> Ash.Query.filter(group_id == ^group_id and user_id == ^user_id)
    |> Ash.Query.load([:user, :avatar_url])
    |> Ash.read_one(authorize?: false, domain: __MODULE__)
  end

  def get_membership(_group_id, _user_id), do: {:ok, nil}

  def get_membership_by_username(%Group{id: group_id}, username),
    do: get_membership_by_username(group_id, username)

  def get_membership_by_username(group_id, username)
      when is_binary(group_id) and is_binary(username) and username != "" do
    GroupUserRelation
    |> Ash.Query.filter(group_id == ^group_id and username == ^username)
    |> Ash.Query.load([:user, :avatar_url])
    |> Ash.read_one(authorize?: false, domain: __MODULE__)
  end

  def get_membership_by_username(_group_id, _username), do: {:ok, nil}

  def list_memberships(%Group{id: group_id}, user_ids),
    do: list_memberships(group_id, user_ids)

  def list_memberships(group_id, user_ids)
      when is_binary(group_id) and is_list(user_ids) do
    normalized_user_ids =
      user_ids
      |> Enum.filter(&is_binary/1)
      |> Enum.uniq()

    case {Ecto.UUID.cast(group_id), normalized_user_ids} do
      {_cast_result, []} ->
        {:ok, []}

      {:error, _user_ids} ->
        {:ok, []}

      {{:ok, _uuid}, _user_ids} ->
        memberships =
          GroupUserRelation
          |> Ash.Query.filter(group_id == ^group_id and user_id in ^normalized_user_ids)
          |> Ash.Query.load([:user, :avatar_url])
          |> Ash.read!(authorize?: false, domain: __MODULE__)

        {:ok, memberships}
    end
  end

  def list_memberships(_group_id, _user_ids), do: {:ok, []}

  def list_memberships_by_user_id(group_id, user_ids) do
    case list_memberships(group_id, user_ids) do
      {:ok, memberships} -> {:ok, Map.new(memberships, &{&1.user_id, &1})}
      {:error, error} -> {:error, error}
    end
  end

  def membership_id_to_username_map(group_id) when is_binary(group_id) do
    group_id
    |> memberships_with_usernames()
    |> Map.new(&{&1.id, &1.username})
  end

  def membership_id_to_username_map(_group_id), do: %{}

  def username_to_membership_id_map(group_id) when is_binary(group_id) do
    group_id
    |> memberships_with_usernames()
    |> Map.new(&{&1.username, &1.id})
  end

  def username_to_membership_id_map(_group_id), do: %{}

  def present_membership(%GroupUserRelation{} = membership) do
    user = membership.user
    username = membership.username
    avatar_url = membership.avatar_url

    %{
      avatar_url: avatar_url,
      display_name: present_membership_display_name(username, user),
      user: user,
      username: username
    }
  end

  def present_membership(_membership),
    do: %{avatar_url: nil, display_name: nil, user: nil, username: nil}

  defp present_membership_display_name(username, _user)
       when is_binary(username) and username != "",
       do: username

  defp present_membership_display_name(_username, %User{} = user), do: to_string(user)
  defp present_membership_display_name(_username, _user), do: nil

  defp memberships_with_usernames(group_id) do
    GroupUserRelation
    |> Ash.Query.filter(group_id == ^group_id and not is_nil(username))
    |> Ash.Query.sort(username: :asc)
    |> Ash.read!(authorize?: false, domain: __MODULE__)
  end
end
