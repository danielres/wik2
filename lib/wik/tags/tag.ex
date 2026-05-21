defmodule Wik.Tags.Tag do
  alias Wik.Accounts.Space
  alias Wik.Changes.SetSpaceFromCurrentTenant
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
      change SetSpaceFromCurrentTenant
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

  pub_sub do
    module WikWeb.Endpoint
    prefix "tag"
    publish :create, ["space", :space_id]
    publish :update, ["space", :space_id]
    publish :destroy, ["space", :space_id]
  end

  multitenancy do
    strategy :attribute
    attribute :space_id
    parse_attribute {Wik.Accounts, :space_slug_to_id, []}
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
    belongs_to :space, Wik.Accounts.Space do
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
    identity :unique_space_slug, [:space_id, :slug]
    identity :unique_space_scoped_id, [:id, :space_id]
  end

  def space_pub_sub_topic(space_id), do: "tag:space:#{space_id}"
end

defimpl String.Chars, for: Wik.Tags.Tag do
  def to_string(%Wik.Tags.Tag{name: name}), do: name
end
