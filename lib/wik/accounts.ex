defmodule Wik.Accounts do
  import Ecto.Query, only: [from: 2]

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

    resource Wik.Accounts.Space do
      define :get_space_by_slug, action: :read, get_by_identity: :unique_slug

      # TODO: filter by actor
      define :list_spaces,
        action: :read,
        args: [],
        default_options: [
          query: [sort: [inserted_at: :desc]],
          load: [:author]
        ]
    end

    resource Wik.Accounts.Membership
  end

  require Ash.Query

  alias Wik.Accounts.Space
  alias Wik.Accounts.Membership
  alias Wik.Blocks
  alias Wik.Blocks.Block
  alias Wik.Repo
  alias Wik.Accounts.User
  alias Utils.Values

  # TODO: rename to: list_user_owned_spaces
  def list_owned_spaces(%User{id: user_id}) do
    owned_space_ids =
      from(membership in "memberships",
        where: membership.user_id == type(^user_id, Ecto.UUID) and membership.type == "owner",
        select: membership.space_id
      )
      |> Repo.all()

    Space
    |> Ash.Query.filter(id in ^owned_space_ids)
    |> Ash.Query.sort(name: :asc)
    |> Ash.read(authorize?: false, domain: __MODULE__)
  end

  def space_slug_to_id(space_slug) when is_binary(space_slug) do
    case get_space_by_slug(space_slug, authorize?: false) do
      {:ok, %{id: id}} -> id
      {:error, _reason} -> nil
    end
  end

  def space_slug_to_id(_), do: nil

  # TODO: inline?
  def tenant_to_space_id(%Space{id: space_id}), do: space_id

  def tenant_to_space_id(space_id_or_slug) when is_binary(space_id_or_slug) do
    if canonical_uuid?(space_id_or_slug) do
      space_id_or_slug
    else
      space_slug_to_id(space_id_or_slug)
    end
  end

  def tenant_to_space_id(_), do: nil

  defp canonical_uuid?(value) do
    String.match?(
      value,
      ~r/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/
    )
  end

  def get_membership(space_or_space_id, user_or_user_id)

  def get_membership(%Space{id: space_id}, %User{id: user_id}),
    do: get_membership(space_id, user_id)

  def get_membership(space_id, user_id) when is_binary(space_id) and is_binary(user_id) do
    Membership
    |> Ash.Query.filter(space_id == ^space_id and user_id == ^user_id)
    |> Ash.Query.load(membership_load())
    |> Ash.read_one(authorize?: false, domain: __MODULE__)
  end

  def get_membership(_space_id, _user_id), do: {:ok, nil}

  def get_membership_by_username(%Space{id: space_id}, username),
    do: get_membership_by_username(space_id, username)

  def get_membership_by_username(space_id, username)
      when is_binary(space_id) and is_binary(username) and username != "" do
    Membership
    |> Ash.Query.filter(space_id == ^space_id and username == ^username)
    |> Ash.Query.load(membership_load())
    |> Ash.read_one(authorize?: false, domain: __MODULE__)
  end

  def get_membership_by_username(_space_id, _username), do: {:ok, nil}

  def list_memberships(space_or_space_id, user_ids)

  def list_memberships(%Space{id: space_id}, user_ids),
    do: list_memberships(space_id, user_ids)

  def list_memberships(space_id, user_ids)
      when is_binary(space_id) and is_list(user_ids) do
    normalized_user_ids =
      user_ids
      |> Enum.filter(&is_binary/1)
      |> Enum.uniq()

    case {Ecto.UUID.cast(space_id), normalized_user_ids} do
      {_cast_result, []} ->
        {:ok, []}

      {:error, _user_ids} ->
        {:ok, []}

      {{:ok, _uuid}, _user_ids} ->
        Membership
        |> Ash.Query.filter(space_id == ^space_id and user_id in ^normalized_user_ids)
        |> Ash.Query.load(membership_load())
        |> Ash.read(authorize?: false, domain: __MODULE__)
    end
  end

  def list_memberships(_space_id, _user_ids), do: {:ok, []}

  def list_memberships_by_user_id(space_id, user_ids) do
    case list_memberships(space_id, user_ids) do
      {:ok, memberships} -> {:ok, Map.new(memberships, &{&1.user_id, &1})}
      {:error, error} -> {:error, error}
    end
  end

  def membership_id_to_username_map(space_id) when is_binary(space_id) do
    space_id
    |> memberships_with_usernames()
    |> Map.new(&{&1.id, &1.username})
  end

  def membership_id_to_username_map(_space_id), do: %{}

  def username_to_membership_id_map(space_id) when is_binary(space_id) do
    space_id
    |> memberships_with_usernames()
    |> Map.new(&{&1.username, &1.id})
  end

  def username_to_membership_id_map(_space_id), do: %{}

  def present_membership(%Membership{} = membership) do
    user = membership.user
    username = membership.username
    avatar_url = membership.avatar_url

    %{
      avatar_url: avatar_url,
      display_name: present_membership_display_name(username, user),
      space: Map.get(membership, :space),
      user: user,
      username: username
    }
  end

  def present_membership(_membership),
    do: %{avatar_url: nil, display_name: nil, space: nil, user: nil, username: nil}

  def get_primary_block(%Membership{} = membership, _opts \\ []),
    do: membership_primary_block(membership)

  def get_or_create_primary_block(%Membership{} = membership, opts \\ []) do
    scope = Keyword.fetch!(opts, :scope)

    Blocks.get_or_create_primary_block(membership,
      get_existing: fn membership ->
        case membership_primary_block(membership) do
          {:ok, block} -> block
          {:error, error} -> {:error, error}
        end
      end,
      create_block: fn -> Blocks.create_user_owned_block(%{type: :markdown}, scope: scope) end,
      attach_block: fn membership, block ->
        Ash.update(
          membership,
          %{primary_block_id: block.id},
          action: :set_primary_block,
          scope: scope
        )
      end
    )
  end

  def update_primary_block(%Membership{} = membership, params, opts \\ []) do
    with {:ok, _membership, %Block{} = block} <-
           get_or_create_primary_block(membership, opts) do
      Blocks.update_block(block, params, opts)
    end
  end

  defp present_membership_display_name(username, _user)
       when is_binary(username) and username != "",
       do: username

  defp present_membership_display_name(_username, %User{} = user) do
    user
    |> external_identity_display_name()
    |> Values.blank_to_nil()
    |> case do
      nil -> user |> to_string() |> Values.blank_to_nil()
      display_name -> display_name
    end
  end

  defp present_membership_display_name(_username, _user), do: nil

  defp external_identity_display_name(%User{external_identities: identities})
       when is_list(identities) do
    identities
    |> Enum.find_value(fn identity ->
      identity.username
      |> Values.blank_to_nil()
      |> case do
        nil -> identity.display_name |> Values.blank_to_nil()
        username -> username
      end
    end)
  end

  defp external_identity_display_name(_user), do: nil

  defp memberships_with_usernames(space_id) do
    Membership
    |> Ash.Query.filter(space_id == ^space_id and not is_nil(username))
    |> Ash.Query.sort(username: :asc)
    |> Ash.read!(authorize?: false, domain: __MODULE__)
  end

  defp membership_primary_block(%Membership{primary_block_id: nil}), do: {:ok, nil}

  defp membership_primary_block(%Membership{primary_block_id: primary_block_id}) do
    Block
    |> Ash.Query.filter(id == ^primary_block_id)
    |> Ash.read_one(authorize?: false, domain: Blocks)
  end

  defp membership_primary_block(_membership), do: {:ok, nil}

  defp membership_load, do: [:space, :avatar_url, user: [:external_identities]]
end
