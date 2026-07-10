defmodule Wik.Tags.TagEdge do
  alias Wik.Accounts.Space
  alias Wik.Changes.SetSpaceFromCurrentTenant
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
      reference :parent_tag, on_delete: :delete, match_with: [space_id: :space_id]
      reference :child_tag, on_delete: :delete, match_with: [space_id: :space_id]
    end

    check_constraints do
      check_constraint [:parent_tag_id, :child_tag_id], "tag_edges_no_self_reference",
        check: "parent_tag_id <> child_tag_id",
        message: "parent and child tags must differ"
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
      change SetSpaceFromCurrentTenant
      change ValidateLink
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

    policy action_type(:destroy) do
      authorize_if Space.Checks.ActorCanManageResourceSpace
    end
  end

  pub_sub do
    module WikWeb.Endpoint
    prefix "tag_edge"
    publish :create, ["space", :space_id]
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
  end

  relationships do
    belongs_to :space, Wik.Accounts.Space do
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
    identity :unique_space_parent_child, [:space_id, :parent_tag_id, :child_tag_id]
  end

  def space_pub_sub_topic(space_id), do: "tag_edge:space:#{space_id}"
end
