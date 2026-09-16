defmodule Wik.Library.Field do
  alias Wik.Accounts.Space
  alias Wik.Changes.SetSpaceFromCurrentTenant
  alias Wik.Library.EntryType

  @field_types [
    :boolean,
    :date,
    :email,
    :location,
    :media,
    :number,
    :phone,
    :rich_text,
    :select,
    :text,
    :title,
    :url
  ]

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Library,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "library_fields"
    repo Wik.Repo

    references do
      reference :entry_type, on_delete: :delete, match_with: [space_id: :space_id]
      reference :space, on_delete: :delete
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:key, :label, :options, :order_key, :required?, :type, :type_id]
      change SetSpaceFromCurrentTenant
    end

    update :update do
      accept [:label, :options, :order_key, :required?, :type]
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
    prefix "library_field"
    publish :create, ["type", :type_id]
    publish :update, ["type", :type_id]
    publish :destroy, ["type", :type_id]
  end

  multitenancy do
    strategy :attribute
    attribute :space_id
    parse_attribute {Wik.Accounts, :tenant_to_space_id, []}
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :type, :atom do
      public? true
      allow_nil? false
      constraints one_of: @field_types
    end

    attribute :key, :string do
      public? true
      allow_nil? false
      constraints match: ~r/^[a-z][a-z0-9_]*$/
    end

    attribute :label, :string do
      public? true
      allow_nil? false
      constraints allow_empty?: false
    end

    attribute :options, {:array, :string} do
      public? true
      allow_nil? false
      default []
    end

    attribute :order_key, :string do
      public? true
      allow_nil? false
    end

    attribute :required?, :boolean do
      source :required
      public? true
      allow_nil? false
      default false
    end
  end

  relationships do
    belongs_to :entry_type, EntryType do
      source_attribute :type_id
      allow_nil? false
    end

    belongs_to :space, Space, do: allow_nil?(false)
  end

  identities do
    identity :unique_type_key, [:type_id, :key]
    identity :unique_type_order, [:type_id, :order_key]
    identity :unique_space_scoped_id, [:id, :space_id]
  end
end
