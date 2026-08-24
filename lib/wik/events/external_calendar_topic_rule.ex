defmodule Wik.Events.ExternalCalendarTopicRule do
  alias Wik.Accounts.Space
  alias Wik.Changes.SetSpaceFromCurrentTenant
  alias Wik.Events.ExternalCalendarSubscription
  alias Wik.Events.ExternalCalendarTopicRule.Changes.NormalizeAliases
  alias Wik.Events.ExternalCalendarTopicRule.Validations.MatchFields
  alias Wik.Tags.Tag

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Events,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  postgres do
    table "external_calendar_topic_rules"
    repo Wik.Repo
    identity_index_names unique_space_subscription_tag: "ext_cal_topic_rules_space_sub_tag_idx"

    references do
      reference :subscription, on_delete: :delete, match_with: [space_id: :space_id]
      reference :tag, on_delete: :delete, match_with: [space_id: :space_id]
    end
  end

  admin do
    relationship_display_fields [:id]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:aliases, :enabled, :match_description, :match_title, :subscription_id, :tag_id]
      change SetSpaceFromCurrentTenant
      change NormalizeAliases
    end

    update :update do
      accept [:aliases, :enabled, :match_description, :match_title]
      require_atomic? false
      change NormalizeAliases
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if Space.Checks.ActorIsMemberOfResourceSpace
    end

    policy action_type(:create) do
      authorize_if Space.Checks.ActorCanManageCurrentTenantSpace
    end

    policy action_type(:update) do
      authorize_if Space.Checks.ActorCanManageResourceSpace
    end

    policy action_type(:destroy) do
      authorize_if Space.Checks.ActorCanManageResourceSpace
    end
  end

  validations do
    validate MatchFields
  end

  multitenancy do
    strategy :attribute
    attribute :space_id
    parse_attribute {Wik.Accounts, :tenant_to_space_id, []}
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :aliases, {:array, :string} do
      public? true
      allow_nil? false
      default []
    end

    attribute :enabled, :boolean do
      public? true
      allow_nil? false
      default true
    end

    attribute :match_description, :boolean do
      public? true
      allow_nil? false
      default true
    end

    attribute :match_title, :boolean do
      public? true
      allow_nil? false
      default true
    end
  end

  relationships do
    belongs_to :space, Wik.Accounts.Space do
      destination_attribute :id
      allow_nil? false
    end

    belongs_to :subscription, ExternalCalendarSubscription do
      destination_attribute :id
      allow_nil? false
    end

    belongs_to :tag, Tag do
      destination_attribute :id
      allow_nil? false
    end
  end

  identities do
    identity :unique_space_subscription_tag, [:space_id, :subscription_id, :tag_id]
  end
end
