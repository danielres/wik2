defmodule Wik.Events.ExternalEvent do
  alias Wik.Accounts.Space
  alias Wik.Events.ExternalCalendarSubscription

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Events,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "external_events"
    repo Wik.Repo

    identity_index_names unique_occurrence_per_subscription:
                           "external_events_subscription_occurrence_idx"

    references do
      reference :subscription, on_delete: :delete
    end
  end

  actions do
    defaults [:read]
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if Space.Checks.ActorIsMemberOfCurrentTenantSpace
    end
  end

  multitenancy do
    strategy :attribute
    attribute :space_id
    parse_attribute {Wik.Accounts, :space_slug_to_id, []}
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :external_uid, :string do
      allow_nil? false
      public? false
    end

    attribute :external_recurrence_id, :string do
      allow_nil? true
      public? false
    end

    attribute :external_occurrence_key, :string do
      allow_nil? false
      public? false
    end

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :starts_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :ends_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :all_day, :boolean do
      allow_nil? false
      default false
      public? true
    end

    attribute :tz, :string do
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:draft, :published, :cancelled]
      allow_nil? false
      default :published
      public? true
    end

    attribute :location, :string do
      allow_nil? true
      public? true
    end

    attribute :description, :string do
      allow_nil? true
      public? true
    end

    attribute :event_url, :string do
      allow_nil? true
      public? true
    end

    attribute :calendar_name, :string do
      allow_nil? true
      public? true
    end

    attribute :last_seen_at, :utc_datetime_usec do
      allow_nil? false
      public? false
    end

    attribute :source_missing_at, :utc_datetime_usec do
      allow_nil? true
      public? true
    end
  end

  relationships do
    belongs_to :space, Wik.Accounts.Space do
      destination_attribute :id
      allow_nil? false
    end

    belongs_to :subscription, ExternalCalendarSubscription do
      source_attribute :subscription_id
      destination_attribute :id
      allow_nil? false
    end

    has_one :linked_event, Wik.Events.Event do
      destination_attribute :source_external_event_id
    end
  end

  identities do
    identity :unique_occurrence_per_subscription, [
      :subscription_id,
      :external_uid,
      :external_occurrence_key
    ]
  end
end
