defmodule Qblog.Access.Grant do
  use Ash.Resource,
    otp_app: :qblog,
    domain: Qblog.Access,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  alias Qblog.Access.ExternalIdentity
  alias Qblog.Access.Source
  alias Qblog.Accounts.User

  postgres do
    table "access_grants"
    repo Qblog.Repo
  end

  admin do
    table_columns [:source, :user, :status, :last_verified_at]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [:external_identity_id, :last_verified_at, :source_id, :status, :user_id]
    end

    create :upsert do
      accept [:external_identity_id, :last_verified_at, :source_id, :status, :user_id]

      upsert? true
      upsert_identity :unique_source_user
      upsert_fields [:external_identity_id, :last_verified_at, :status]
    end

    update :update do
      accept [:external_identity_id, :last_verified_at, :status]
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if relates_to_actor_via(:user)
    end
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :last_verified_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      constraints one_of: [:active, :inactive]
      default :active
      public? true
    end
  end

  relationships do
    belongs_to :external_identity, ExternalIdentity do
      allow_nil? false
    end

    belongs_to :source, Source do
      allow_nil? false
    end

    belongs_to :user, User do
      allow_nil? false
    end
  end

  identities do
    identity :unique_source_user, [:source_id, :user_id]
  end
end
