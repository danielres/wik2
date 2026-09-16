defmodule Wik.Library.Entry do
  alias Wik.Accounts.Space
  alias Wik.Accounts.User
  alias Wik.Changes.SetSpaceFromCurrentTenant
  alias Wik.Library.BlockReference
  alias Wik.Library.Entry.Checks.ActorCanCreateForType
  alias Wik.Library.Entry.Changes.NormalizeValues
  alias Wik.Library.EntryType

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Library,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "library_entries"
    repo Wik.Repo

    references do
      reference :type, on_delete: :restrict, match_with: [space_id: :space_id]
      reference :space, on_delete: :delete
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:external_media_metadata, :type_id, :values]
      change SetSpaceFromCurrentTenant
      change relate_actor(:creator, allow_nil?: false)
      change NormalizeValues
    end

    update :update do
      accept [:external_media_metadata, :values]
      require_atomic? false
      change NormalizeValues
    end

    destroy :destroy do
      primary? true
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin), do: authorize_if(always())

    policy action_type(:read), do: authorize_if(Space.Checks.ActorIsMemberOfResourceSpace)

    policy action_type(:create) do
      forbid_unless Space.Checks.ActorIsMemberOfCurrentTenantSpace
      authorize_if ActorCanCreateForType
    end

    policy action_type(:update) do
      authorize_if relates_to_actor_via(:creator)
      authorize_if Space.Checks.ActorCanManageResourceSpace
    end

    policy action_type(:destroy) do
      authorize_if relates_to_actor_via(:creator)
      authorize_if Space.Checks.ActorCanManageResourceSpace
    end
  end

  pub_sub do
    module WikWeb.Endpoint
    prefix "library_entry"
    publish :create, ["space", :space_id]
    publish :update, [:id]
    publish :update, ["space", :space_id]
    publish :destroy, [:id]
    publish :destroy, ["space", :space_id]
  end

  multitenancy do
    strategy :attribute
    attribute :space_id
    parse_attribute {Wik.Accounts, :tenant_to_space_id, []}
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :external_media_metadata, :map do
      public? false
      allow_nil? true
    end

    attribute :values, :map do
      public? true
      allow_nil? false
      default %{}
    end
  end

  relationships do
    belongs_to :creator, User, do: allow_nil?(false)

    belongs_to :type, EntryType do
      source_attribute :type_id
      allow_nil? false
    end

    belongs_to :space, Space, do: allow_nil?(false)

    has_many :block_references, BlockReference do
      destination_attribute :entry_id
    end
  end

  identities do
    identity :unique_space_scoped_id, [:id, :space_id]
  end
end
