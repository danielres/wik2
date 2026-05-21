defmodule Wik.Events.EventPublication do
  alias Wik.Accounts.Space
  alias Wik.Events.EventPublication.Checks.ActorCanRelayEvent
  alias Wik.Events.EventPublication.Validations.SpaceMatchesEvent

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Events,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshPhoenix],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "event_publications"
    repo Wik.Repo
  end

  code_interface do
    define :publish_to_origin_space, action: :publish_to_origin_space
    define :relay_to_space, action: :relay_to_space
  end

  actions do
    defaults [:read]

    create :publish_to_origin_space do
      accept [:event_id]
      change relate_actor(:published_by, allow_nil?: false)
      change set_attribute(:publication_type, :origin)
    end

    create :relay_to_space do
      accept [:event_id, :relay_note]
      change relate_actor(:published_by, allow_nil?: false)
      change set_attribute(:publication_type, :relay)
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if Space.Checks.ActorIsMemberOfResourceSpace
    end

    policy action(:publish_to_origin_space) do
      authorize_if Space.Checks.ActorCanManageCurrentTenantSpace
    end

    policy action(:relay_to_space) do
      authorize_if ActorCanRelayEvent
    end
  end

  pub_sub do
    module WikWeb.Endpoint
    prefix "event_publication"
    publish :publish_to_origin_space, ["space", :target_space_id]
    publish :relay_to_space, ["space", :target_space_id]
  end

  validations do
    validate SpaceMatchesEvent
  end

  multitenancy do
    strategy :attribute
    attribute :target_space_id
    parse_attribute {Wik.Accounts, :space_slug_to_id, []}
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :publication_type, :atom do
      constraints one_of: [:origin, :relay]
      public? true
      allow_nil? false
    end

    attribute :relay_note, :string do
      public? true
      allow_nil? true
    end
  end

  relationships do
    belongs_to :event, Wik.Events.Event do
      destination_attribute :id
      allow_nil? false
    end

    belongs_to :space, Wik.Accounts.Space do
      source_attribute :target_space_id
      destination_attribute :id
      allow_nil? false
    end

    belongs_to :published_by, Wik.Accounts.User do
      destination_attribute :id
      allow_nil? false
    end
  end

  identities do
    identity :unique_event_publication, [:event_id, :target_space_id]
  end
end
