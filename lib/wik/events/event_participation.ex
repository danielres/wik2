defmodule Wik.Events.EventParticipation do
  alias Wik.Accounts.Membership
  alias Wik.Accounts.Space
  alias Wik.Changes.SetSpaceFromCurrentTenant
  alias Wik.Events.EventParticipation.Checks.ActorCanManageOwnParticipation
  alias Wik.Events.EventParticipation.Validations.ExactlyOneTarget
  alias Wik.Events.EventPublication
  alias Wik.Events.ExternalEvent

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Events,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "event_participations"
    repo Wik.Repo

    references do
      reference :publication, on_delete: :delete
      reference :external_event, on_delete: :delete
      reference :membership, on_delete: :delete, match_with: [space_id: :space_id]
    end

    check_constraints do
      check_constraint [:publication_id, :external_event_id],
                       "event_participations_exactly_one_target",
                       check: "(publication_id IS NULL) != (external_event_id IS NULL)",
                       message: "must target exactly one event"
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:publication_id, :external_event_id, :membership_id, :interest, :extra_info]

      change SetSpaceFromCurrentTenant
    end

    update :update_details do
      accept [:interest, :extra_info]
      require_atomic? false
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if Space.Checks.ActorIsMemberOfResourceSpace
    end

    policy action(:create) do
      authorize_if ActorCanManageOwnParticipation
    end

    policy action(:update_details) do
      authorize_if ActorCanManageOwnParticipation
    end

    policy action_type(:destroy) do
      authorize_if ActorCanManageOwnParticipation
    end
  end

  pub_sub do
    module WikWeb.Endpoint
    prefix "event_participation"
    publish :create, ["space", :space_id]
    publish :update_details, ["space", :space_id]
    publish :destroy, ["space", :space_id]
  end

  validations do
    validate ExactlyOneTarget
  end

  multitenancy do
    strategy :attribute
    attribute :space_id
    parse_attribute {Wik.Accounts, :tenant_to_space_id, []}
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :interest, :integer do
      public? true
      allow_nil? false
      constraints min: 0, max: 10
    end

    attribute :extra_info, :string do
      public? true
      allow_nil? true
    end
  end

  relationships do
    belongs_to :space, Wik.Accounts.Space do
      destination_attribute :id
      allow_nil? false
    end

    belongs_to :publication, EventPublication do
      destination_attribute :id
      allow_nil? true
    end

    belongs_to :external_event, ExternalEvent do
      destination_attribute :id
      allow_nil? true
    end

    belongs_to :membership, Membership do
      destination_attribute :id
      allow_nil? false
    end
  end

  identities do
    identity :unique_publication_membership, [:publication_id, :membership_id]
    identity :unique_external_event_membership, [:external_event_id, :membership_id]
  end
end
