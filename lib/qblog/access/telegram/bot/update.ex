defmodule Qblog.Access.Telegram.Bot.Update do
  use Ash.Resource,
    otp_app: :qblog,
    domain: Qblog.Access,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  alias Qblog.Access.Telegram.Bot.Update.Summary

  postgres do
    table "access_telegram_bot_updates"
    repo Qblog.Repo
  end

  admin do
    table_columns [:update_id, :inserted_at]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [:payload, :summary, :update_id]
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin) do
      authorize_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :payload, :map do
      allow_nil? false
      public? true
    end

    attribute :summary, Summary do
      allow_nil? false
      public? true
    end

    attribute :update_id, :integer do
      allow_nil? false
      public? true
    end
  end
end
