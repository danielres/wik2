defmodule Wik.Tags.Tag do
  alias Wik.Accounts.Group
  alias Wik.Changes.SetGroupFromCurrentTenant
  alias Wik.Tags.TagEdge

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Tags,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource, AshPhoenix],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "tags"
    repo Wik.Repo
  end

  admin do
    label_field :name
    relationship_display_fields [:name]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:slug, :name, :description]
      change SetGroupFromCurrentTenant
    end

    update :update do
      accept [:slug, :name, :description]
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if Group.Checks.ActorIsMemberOfResourceGroup
    end

    policy action_type(:create) do
      authorize_if Group.Checks.ActorCanManageCurrentTenantGroup
    end

    policy action_type(:update) do
      authorize_if Group.Checks.ActorCanManageResourceGroup
    end

    policy action_type(:destroy) do
      authorize_if Group.Checks.ActorCanManageResourceGroup
    end
  end

  pub_sub do
    module WikWeb.Endpoint
    prefix "tag"
    publish :create, ["group", :group_id]
    publish :update, ["group", :group_id]
    publish :destroy, ["group", :group_id]
  end

  multitenancy do
    strategy :attribute
    attribute :group_id
    parse_attribute {Wik.Accounts, :group_slug_to_id, []}
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :slug, Wik.Types.Slug do
      public? true
      allow_nil? false
    end

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :description, :string do
      public? true
      allow_nil? true
    end
  end

  relationships do
    belongs_to :group, Wik.Accounts.Group do
      destination_attribute :id
      allow_nil? false
    end

    has_many :outgoing_edges, TagEdge do
      source_attribute :id
      destination_attribute :parent_tag_id
    end

    has_many :incoming_edges, TagEdge do
      source_attribute :id
      destination_attribute :child_tag_id
    end
  end

  identities do
    identity :unique_group_slug, [:group_id, :slug]
    identity :unique_group_scoped_id, [:id, :group_id]
  end

  def group_pub_sub_topic(group_id), do: "tag:group:#{group_id}"
end

defimpl String.Chars, for: Wik.Tags.Tag do
  def to_string(%Wik.Tags.Tag{name: name}), do: name
end
