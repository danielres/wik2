defmodule Wik.Access.GoogleEmailAccess do
  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Access,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  alias Wik.Access.Source
  alias Wik.Accounts.Space
  alias Wik.Accounts.User

  postgres do
    table "access_google_email_accesses"
    repo Wik.Repo
  end

  admin do
    label_field :email
    table_columns [:space, :email, :membership_type, :revoked_at]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :email,
        :granted_by_user_id,
        :membership_type,
        :revoked_at,
        :revoked_by_user_id,
        :source_id,
        :space_id
      ]
    end

    create :upsert do
      accept [
        :email,
        :granted_by_user_id,
        :membership_type,
        :revoked_at,
        :revoked_by_user_id,
        :source_id,
        :space_id
      ]

      upsert? true
      upsert_identity :unique_source_email
      upsert_fields [:granted_by_user_id, :membership_type, :revoked_at, :revoked_by_user_id]
    end

    update :revoke do
      accept [:revoked_at, :revoked_by_user_id]
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if Wik.Accounts.Space.Checks.ActorIsMemberOfResourceSpace
    end

    policy action([:create, :upsert, :revoke, :destroy]) do
      authorize_if Wik.Accounts.Space.Checks.ActorCanManageResourceSpace
    end
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :email, :string do
      allow_nil? false
      public? true
    end

    attribute :membership_type, :atom do
      allow_nil? false
      constraints one_of: [:admin, :member]
      default :member
      public? true
    end

    attribute :revoked_at, :utc_datetime_usec do
      public? true
    end
  end

  relationships do
    belongs_to :granted_by_user, User do
      allow_nil? false
    end

    belongs_to :revoked_by_user, User do
      allow_nil? true
    end

    belongs_to :source, Source do
      allow_nil? false
    end

    belongs_to :space, Space do
      allow_nil? false
    end
  end

  identities do
    identity :unique_source_email, [:source_id, :email]
  end
end
