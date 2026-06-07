defmodule Wik.Events.Event do
  alias Wik.Accounts.Space
  alias Wik.Changes.SetSpaceFromCurrentTenant
  alias Wik.Events.Event.Checks.ActorCanReadRelayedEvent
  alias Wik.Events.Event.Changes.CreateOriginPublication
  alias Wik.Events.Event.Changes.SetScheduleFromLocalFields
  alias Wik.Events.Event.Validations.Timing
  alias Wik.Events.Event.Validations.Tz
  alias Wik.Events.ExternalEvent

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Events,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshPhoenix],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "events"
    repo Wik.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :all_day,
        :description,
        :location,
        :relay_policy,
        :tz,
        :title
      ]

      argument :starts_on, :date do
        allow_nil? true
      end

      argument :starts_at_time, :time do
        allow_nil? true
      end

      argument :ends_on, :date do
        allow_nil? true
      end

      argument :ends_at_time, :time do
        allow_nil? true
      end

      change relate_actor(:author, allow_nil?: false)
      change SetSpaceFromCurrentTenant
      change SetScheduleFromLocalFields
      change CreateOriginPublication

      validate present(:title)
      validate present(:location)
      validate present(:tz)
      validate present(:starts_at)
    end

    create :create_from_external do
      accept [
        :description,
        :source_external_event_id,
        :title
      ]

      change relate_actor(:author, allow_nil?: false)
      change SetSpaceFromCurrentTenant
      change CreateOriginPublication
    end

    update :update do
      accept [
        :all_day,
        :description,
        :location,
        :relay_policy,
        :status,
        :tz,
        :title
      ]

      argument :starts_on, :date do
        allow_nil? true
      end

      argument :starts_at_time, :time do
        allow_nil? true
      end

      argument :ends_on, :date do
        allow_nil? true
      end

      argument :ends_at_time, :time do
        allow_nil? true
      end

      change SetScheduleFromLocalFields
      require_atomic? false

      validate present(:title)
      validate present(:location)
      validate present(:tz)
      validate present(:starts_at)
    end

    update :update_local_overlay do
      accept [:description, :title]
      require_atomic? false
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if Space.Checks.ActorIsMemberOfResourceSpace
      authorize_if ActorCanReadRelayedEvent
    end

    policy action(:create) do
      authorize_if Space.Checks.ActorCanManageCurrentTenantSpace
    end

    policy action(:create_from_external) do
      authorize_if Space.Checks.ActorIsMemberOfCurrentTenantSpace
    end

    policy action_type(:update) do
      authorize_if Space.Checks.ActorCanManageResourceSpace
    end
  end

  pub_sub do
    module WikWeb.Endpoint
    prefix "event"
    publish :create, ["space", :space_id]
    publish :create_from_external, ["space", :space_id]
    publish :update, ["space", :space_id]
    publish :update_local_overlay, ["space", :space_id]
  end

  validations do
    validate Timing
    validate Tz
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :all_day, :boolean do
      public? true
      allow_nil? false
      default false
    end

    attribute :description, :string do
      public? true
      allow_nil? true
    end

    attribute :ends_at, :utc_datetime do
      public? true
      allow_nil? true
    end

    attribute :location, :string do
      public? true
      allow_nil? true
    end

    attribute :relay_policy, :atom do
      constraints one_of: [:internal_only, :admins_only_spaces, :members_to_spaces]
      public? true
      allow_nil? false
      default :internal_only
    end

    attribute :starts_at, :utc_datetime do
      public? true
      allow_nil? true
    end

    attribute :tz, :string do
      public? true
      allow_nil? true
    end

    attribute :status, :atom do
      constraints one_of: [:draft, :published, :cancelled]
      public? true
      allow_nil? false
      default :published
    end

    attribute :title, :string do
      public? true
      allow_nil? true
    end
  end

  relationships do
    belongs_to :author, Wik.Accounts.User do
      destination_attribute :id
      allow_nil? false
    end

    belongs_to :space, Wik.Accounts.Space do
      destination_attribute :id
      allow_nil? false
    end

    belongs_to :source_external_event, ExternalEvent do
      destination_attribute :id
      allow_nil? true
    end

    has_many :publications, Wik.Events.EventPublication do
      destination_attribute :event_id
    end
  end

  identities do
    identity :unique_source_external_event, [:source_external_event_id]
  end
end
