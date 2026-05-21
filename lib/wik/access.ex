defmodule Wik.Access do
  use Ash.Domain,
    otp_app: :wik,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  alias Wik.Access.Telegram
  alias Wik.Access.ExternalIdentity
  alias Wik.Access.Grant
  alias Wik.Accounts.User

  require Ash.Query

  admin do
    show? true
  end

  resources do
    resource Wik.Access.ExternalIdentity do
      define :create_external_identity, action: :create

      define :get_external_identity_by_provider_user_id,
        action: :read,
        get_by: [:provider, :provider_user_id]

      define :upsert_external_identity, action: :upsert
    end

    resource Wik.Access.Source do
      define :create_source, action: :create

      define :get_source_by_provider_source_id,
        action: :read,
        get_by: [:provider, :provider_source_id]

      define :upsert_pending_source_from_provider, action: :upsert_pending_from_provider
      define :upsert_source, action: :upsert
    end

    resource Wik.Access.Grant do
      define :create_grant, action: :create
      define :get_grant_by_source_and_user, action: :read, get_by: [:source_id, :user_id]
      define :upsert_grant, action: :upsert
    end

    resource Wik.Access.Telegram.Bot.Update do
      define :create_telegram_bot_update, action: :create
    end
  end

  # TODO: access Telegram directly in call sites, instead of relying on defdelegate.
  defdelegate telegram_create_bot_update(update),
    to: Telegram,
    as: :create_bot_update

  defdelegate telegram_find_or_create_identity(telegram_user),
    to: Telegram,
    as: :find_or_create_identity

  defdelegate telegram_upsert_pending_source(attrs),
    to: Telegram,
    as: :upsert_pending_source

  defdelegate telegram_list_claimable_sources(user),
    to: Telegram,
    as: :list_claimable_sources

  defdelegate telegram_claim_source_with_new_space(source_id, space_attrs, user),
    to: Telegram,
    as: :claim_source_with_new_space

  defdelegate telegram_claim_source_with_existing_space(source_id, space_id, user),
    to: Telegram,
    as: :claim_source_with_existing_space

  defdelegate telegram_refresh_grants(user),
    to: Telegram,
    as: :refresh_grants

  defdelegate telegram_list_bot_updates(actor),
    to: Telegram,
    as: :list_bot_updates

  defdelegate telegram_get_bot_update(id, actor),
    to: Telegram,
    as: :get_bot_update

  def list_user_external_identities(%User{id: user_id}) do
    ExternalIdentity
    |> Ash.Query.filter(user_id == ^user_id)
    |> Ash.Query.sort(updated_at: :desc)
    |> Ash.read(authorize?: false, domain: __MODULE__)
  end

  def get_telegram_user_id_by_provider_user_id(provider_user_id) do
    ExternalIdentity
    |> Ash.Query.filter(provider == :telegram and provider_user_id == ^provider_user_id)
    |> Ash.Query.select([:user_id])
    |> Ash.read_one(authorize?: false, domain: __MODULE__)
    |> case do
      {:ok, %{user_id: user_id}} -> {:ok, user_id}
      {:ok, nil} -> {:ok, nil}
      {:error, error} -> {:error, error}
    end
  end

  def list_user_grants(%User{id: user_id}) do
    Grant
    |> Ash.Query.filter(user_id == ^user_id)
    |> Ash.Query.sort(last_verified_at: :desc)
    |> Ash.read(
      authorize?: false,
      domain: __MODULE__,
      load: [:external_identity, source: [space: [:memberships]]]
    )
  end

  def get_user_space_avatar_url(%User{id: user_id}, %{id: space_id}) do
    case list_space_avatar_urls(space_id, [user_id]) do
      {:ok, avatar_urls} -> {:ok, Map.get(avatar_urls, user_id)}
      {:error, error} -> {:error, error}
    end
  end

  def get_user_space_username_suggestion(%User{id: user_id}, %{id: space_id}) do
    case list_space_grants_for_users(space_id, [user_id]) do
      {:ok, grants} ->
        {:ok, grants_to_username_suggestion(grants, user_id)}

      {:error, error} ->
        {:error, error}
    end
  end

  def list_space_avatar_urls(space_id, user_ids) when is_list(user_ids) do
    normalized_user_ids = user_ids |> Enum.uniq()

    cond do
      is_nil(space_id) ->
        {:ok, %{}}

      normalized_user_ids == [] ->
        {:ok, %{}}

      true ->
        do_list_space_avatar_urls(space_id, normalized_user_ids)
    end
  end

  defp do_list_space_avatar_urls(space_id, user_ids) do
    Grant
    |> Ash.Query.filter(user_id in ^user_ids and source.space_id == ^space_id)
    |> Ash.Query.sort(last_verified_at: :desc)
    |> Ash.read(
      authorize?: false,
      domain: __MODULE__,
      load: [:external_identity]
    )
    |> case do
      {:ok, grants} ->
        {:ok, grants_to_avatar_urls(grants)}

      {:error, error} ->
        {:error, error}
    end
  end

  defp grants_to_avatar_urls(grants) do
    grants
    |> Enum.reduce(%{}, fn
      %{user_id: user_id, external_identity: %{avatar_url: avatar_url}}, avatar_urls
      when is_binary(avatar_url) ->
        Map.put_new(avatar_urls, user_id, avatar_url)

      _grant, avatar_urls ->
        avatar_urls
    end)
  end

  def list_space_grants_for_users(space_id, user_ids) do
    Grant
    |> Ash.Query.filter(source.space_id == ^space_id and user_id in ^user_ids)
    |> Ash.Query.sort(last_verified_at: :desc)
    |> Ash.read(
      authorize?: false,
      domain: __MODULE__,
      load: [:external_identity]
    )
  end

  defp grants_to_username_suggestion(grants, user_id) do
    grants
    |> Enum.find_value(fn
      %{user_id: ^user_id, external_identity: %{username: username}} ->
        normalize_username(username)

      _grant ->
        nil
    end)
  end

  defp normalize_username(username) when is_binary(username) do
    username
    |> String.trim()
    |> String.trim_leading("@")
    |> Utils.Slugify.generate()
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_username(_), do: nil
end
