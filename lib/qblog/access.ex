defmodule Qblog.Access do
  use Ash.Domain,
    otp_app: :qblog,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  alias Qblog.Access.Telegram
  alias Qblog.Accounts.User

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
  end

  def find_or_create_identity_from_telegram(telegram_user) do
    Telegram.find_or_create_identity(telegram_user)
  end

  def upsert_pending_telegram_source(attrs) do
    Telegram.upsert_pending_source(attrs)
  end

  def list_claimable_telegram_sources(%User{} = user) do
    Telegram.list_claimable_sources(user)
  end

  def claim_telegram_source_with_new_group(source_id, %User{} = user) do
    Telegram.claim_source_with_new_group(source_id, user)
  end

  def claim_telegram_source_with_existing_group(source_id, group_id, %User{} = user) do
    Telegram.claim_source_with_existing_group(source_id, group_id, user)
  end

  def refresh_telegram_grants(%User{} = user) do
    Telegram.refresh_grants(user)
  end
end
