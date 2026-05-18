defmodule Wik.Tags.TagEdge do
  alias Wik.Accounts.Group
  alias Wik.Tags.Changes.SetGroupFromCurrentTenant
  alias Wik.Tags.Tag
  alias Wik.Tags.TagEdge.Changes.ValidateLink

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Tags,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "tag_edges"
    repo Wik.Repo

    references do
      reference :parent_tag, on_delete: :delete, match_with: [group_id: :group_id]
      reference :child_tag, on_delete: :delete, match_with: [group_id: :group_id]
    end
  end

  admin do
    relationship_display_fields [:name]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:parent_tag_id, :child_tag_id]
      change SetGroupFromCurrentTenant
      change ValidateLink
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

    policy action_type(:destroy) do
      authorize_if Group.Checks.ActorCanManageResourceGroup
    end
  end

  pub_sub do
    module WikWeb.Endpoint
    prefix "tag_edge"
    publish :create, ["group", :group_id]
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
  end

  relationships do
    belongs_to :group, Wik.Accounts.Group do
      destination_attribute :id
      allow_nil? false
    end

    belongs_to :parent_tag, Tag do
      destination_attribute :id
      allow_nil? false
    end

    belongs_to :child_tag, Tag do
      destination_attribute :id
      allow_nil? false
    end
  end

  identities do
    identity :unique_group_parent_child, [:group_id, :parent_tag_id, :child_tag_id]
  end

  def group_pub_sub_topic(group_id), do: "tag_edge:group:#{group_id}"
end
