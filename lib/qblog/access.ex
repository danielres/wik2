defmodule Qblog.Access do
  use Ash.Domain,
    otp_app: :qblog,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  alias Qblog.Access.Telegram
  alias Qblog.Access.ExternalIdentity
  alias Qblog.Access.Grant
  alias Qblog.Accounts.User

  require Ash.Query

  admin do
    show? true
  end

  resources do
    resource Qblog.Access.ExternalIdentity do
      define :create_external_identity, action: :create

      define :get_external_identity_by_provider_user_id,
        action: :read,
        get_by: [:provider, :provider_user_id]

      define :upsert_external_identity, action: :upsert
    end

    resource Qblog.Access.Source do
      define :create_source, action: :create

      define :get_source_by_provider_source_id,
        action: :read,
        get_by: [:provider, :provider_source_id]

      define :upsert_pending_source_from_provider, action: :upsert_pending_from_provider
      define :upsert_source, action: :upsert
    end

    resource Qblog.Access.Grant do
      define :create_grant, action: :create
      define :get_grant_by_source_and_user, action: :read, get_by: [:source_id, :user_id]
      define :upsert_grant, action: :upsert
    end

    resource Qblog.Access.Telegram.Bot.Update do
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

  defdelegate telegram_claim_source_with_new_group(source_id, user),
    to: Telegram,
    as: :claim_source_with_new_group

  defdelegate telegram_claim_source_with_existing_group(source_id, group_id, user),
    to: Telegram,
    as: :claim_source_with_existing_group

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
      load: [:external_identity, source: [group: [:memberships]]]
    )
  end

  def get_user_group_avatar_url(%User{id: user_id}, %{id: group_id}) do
    Grant
    |> Ash.Query.filter(user_id == ^user_id and source.group_id == ^group_id)
    |> Ash.Query.sort(last_verified_at: :desc)
    |> Ash.read(
      authorize?: false,
      domain: __MODULE__,
      load: [:external_identity]
    )
    |> case do
      {:ok, grants} ->
        grants
        |> Enum.find_value(fn
          %{external_identity: %{avatar_url: avatar_url}} when is_binary(avatar_url) ->
            avatar_url

          _grant ->
            nil
        end)
        |> then(&{:ok, &1})

      {:error, error} ->
        {:error, error}
    end
  end

  def list_group_grants_for_users(group_id, user_ids) do
    Grant
    |> Ash.Query.filter(source.group_id == ^group_id and user_id in ^user_ids)
    |> Ash.Query.sort(last_verified_at: :desc)
    |> Ash.read(
      authorize?: false,
      domain: __MODULE__,
      load: [:external_identity]
    )
  end
end
