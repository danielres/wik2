defmodule Qblog.Access.Source do
  use Ash.Resource,
    otp_app: :qblog,
    domain: Qblog.Access,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  alias Qblog.Access.Grant
  alias Qblog.Accounts.Group
  alias Qblog.Accounts.User

  postgres do
    table "access_sources"
    repo Qblog.Repo
  end

  admin do
    label_field :title
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :claimed_at,
        :claimed_by_user_id,
        :group_id,
        :metadata,
        :provider,
        :provider_source_id,
        :status,
        :title
      ]
    end

    create :upsert do
      accept [
        :claimed_at,
        :claimed_by_user_id,
        :group_id,
        :metadata,
        :provider,
        :provider_source_id,
        :status,
        :title
      ]

      upsert? true
      upsert_identity :unique_provider_source
      upsert_fields [:claimed_at, :claimed_by_user_id, :group_id, :metadata, :status, :title]
    end

    update :update do
      accept [:claimed_at, :claimed_by_user_id, :group_id, :metadata, :status, :title]
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if relates_to_actor_via([:group, :users])
      authorize_if relates_to_actor_via(:claimed_by_user)
    end
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :claimed_at, :utc_datetime_usec do
      public? true
    end

    attribute :metadata, :map do
      allow_nil? false
      default %{}
      public? true
    end

    attribute :provider, :atom do
      allow_nil? false
      constraints one_of: [:telegram]
      public? true
    end

    attribute :provider_source_id, :string do
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      constraints one_of: [:pending, :active, :disabled]
      default :pending
      public? true
    end

    attribute :title, :string do
      allow_nil? false
      public? true
    end
  end

  relationships do
    belongs_to :claimed_by_user, User do
      allow_nil? true
    end

    belongs_to :group, Group do
      allow_nil? true
    end

    has_many :grants, Grant do
      destination_attribute :source_id
    end
  end

  identities do
    identity :unique_provider_source, [:provider, :provider_source_id]
  end
end
