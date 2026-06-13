defmodule Wik.Access.ExternalIdentity do
  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Access,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  alias Wik.Accounts.User
  alias Wik.Access.Grant

  postgres do
    table "access_external_identities"
    repo Wik.Repo
  end

  admin do
    label_field :provider_user_id
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :avatar_url,
        :display_name,
        :email,
        :metadata,
        :provider,
        :provider_user_id,
        :user_id,
        :username
      ]
    end

    create :upsert do
      accept [
        :avatar_url,
        :display_name,
        :email,
        :metadata,
        :provider,
        :provider_user_id,
        :user_id,
        :username
      ]

      upsert? true
      upsert_identity :unique_provider_user
      upsert_fields [:avatar_url, :display_name, :email, :metadata, :username]
    end

    update :update do
      accept [:avatar_url, :display_name, :email, :metadata, :user_id, :username]
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

    attribute :avatar_url, :string do
      public? true
    end

    attribute :display_name, :string do
      public? true
    end

    attribute :email, :string do
      public? true
    end

    attribute :metadata, :map do
      allow_nil? false
      default %{}
      public? true
    end

    attribute :provider, :atom do
      allow_nil? false
      constraints one_of: [:google, :telegram]
      public? true
    end

    attribute :provider_user_id, :string do
      allow_nil? false
      public? true
    end

    attribute :username, :string do
      public? true
    end
  end

  relationships do
    belongs_to :user, User do
      allow_nil? false
    end

    has_many :grants, Grant do
      destination_attribute :external_identity_id
    end
  end

  identities do
    identity :unique_provider_user, [:provider, :provider_user_id]
  end
end
