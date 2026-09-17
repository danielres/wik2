defmodule Wik.Library.EntryType do
  alias Wik.Accounts.Space
  alias Wik.Changes.SetSpaceFromCurrentTenant
  alias Wik.Library.Entry
  alias Wik.Library.Field

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Library,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "library_entry_types"
    repo Wik.Repo

    references do
      reference :space, on_delete: :delete
    end
  end

  admin do
    label_field :name
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:description, :entry_creation_permission, :name, :slug]
      change SetSpaceFromCurrentTenant
    end

    update :update do
      accept [:description, :entry_creation_permission, :name]
    end

    destroy :destroy do
      primary? true
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin), do: authorize_if(always())

    policy action_type(:read), do: authorize_if(Space.Checks.ActorIsMemberOfResourceSpace)
    policy action_type(:create), do: authorize_if(Space.Checks.ActorCanManageCurrentTenantSpace)
    policy action_type(:update), do: authorize_if(Space.Checks.ActorCanManageResourceSpace)
    policy action_type(:destroy), do: authorize_if(Space.Checks.ActorCanManageResourceSpace)
  end

  pub_sub do
    module WikWeb.Endpoint
    prefix "library_entry_type"
    publish :create, ["space", :space_id]
    publish :update, ["space", :space_id]
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

    attribute :description, :string do
      public? true
      allow_nil? false
      default ""
    end

    attribute :entry_creation_permission, :atom do
      public? true
      allow_nil? false
      default :members
      constraints one_of: [:admins, :members]
    end

    attribute :name, :string do
      public? true
      allow_nil? false
      constraints allow_empty?: false
    end

    attribute :slug, Wik.Types.Slug do
      public? true
      allow_nil? false
    end
  end

  relationships do
    belongs_to :space, Space, do: allow_nil?(false)

    has_many :entries, Entry do
      destination_attribute :type_id
    end

    has_many :fields, Field do
      destination_attribute :type_id
      default_sort order_key: :asc
    end
  end

  identities do
    identity :unique_space_slug, [:space_id, :slug]
    identity :unique_space_scoped_id, [:id, :space_id]
  end
end
