defmodule Wik.Events.ExternalCalendarSubscription do
  alias Wik.Accounts.Space

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Events,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshPhoenix]

  postgres do
    table "external_calendar_subscriptions"
    repo Wik.Repo
    identity_index_names unique_subscription_url_per_space: "ext_cal_subs_space_url_idx"
  end

  code_interface do
    define :create, action: :create
    define :destroy, action: :destroy
    define :update_custom_name, action: :update_custom_name
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :ics_url,
        :cached_at,
        :etag,
        :cached_name,
        :cached_tz,
        :cached_desc
      ]
    end

    update :update_custom_name do
      accept [:custom_name]
    end

    update :update_cache do
      accept [
        :cached_at,
        :etag,
        :last_error,
        :cached_name,
        :cached_tz,
        :cached_desc
      ]
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if Space.Checks.ActorIsMemberOfCurrentTenantSpace
    end

    policy action(:create) do
      authorize_if Space.Checks.ActorCanManageCurrentTenantSpace
    end

    policy action(:destroy) do
      authorize_if Space.Checks.ActorCanManageCurrentTenantSpace
    end

    policy action(:update_custom_name) do
      authorize_if Space.Checks.ActorCanManageCurrentTenantSpace
    end
  end

  multitenancy do
    strategy :attribute
    attribute :space_id
    parse_attribute {Wik.Accounts, :tenant_to_space_id, []}
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :ics_url, :string do
      public? true
      allow_nil? false
    end

    attribute :custom_name, :string do
      public? true
      allow_nil? true
    end

    attribute :cached_at, :utc_datetime_usec do
      public? false
      allow_nil? true
    end

    attribute :cached_name, :string do
      public? false
      allow_nil? true
    end

    attribute :cached_tz, :string do
      public? false
      allow_nil? true
    end

    attribute :cached_desc, :string do
      public? false
      allow_nil? true
    end

    attribute :etag, :string do
      public? false
      allow_nil? true
    end

    attribute :last_error, :string do
      public? false
      allow_nil? true
    end
  end

  relationships do
    belongs_to :space, Wik.Accounts.Space do
      destination_attribute :id
      allow_nil? false
    end
  end

  identities do
    identity :unique_subscription_url_per_space, [:space_id, :ics_url]
  end
end
