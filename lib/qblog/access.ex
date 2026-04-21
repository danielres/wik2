defmodule Qblog.Access do
  use Ash.Domain,
    otp_app: :qblog,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  alias Qblog.Access.Telegram

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
end
