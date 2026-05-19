defmodule Wik.Tags.Tagging do
  alias Wik.Accounts.Group
  alias Wik.Accounts.GroupUserRelation
  alias Wik.Changes.SetGroupFromCurrentTenant
  alias Wik.Tags.Tag
  alias Wik.Tags.Tagging.Checks.ActorCanManageOwnMembershipTagging
  alias Wik.Tags.Tagging.Changes.NormalizeMembershipFields
  alias Wik.Tags.Tagging.Changes.ValidateTarget

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Tags,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "taggings"
    repo Wik.Repo

    references do
      reference :tag, on_delete: :delete, match_with: [group_id: :group_id]

      reference :tagged_by_group_user_relation,
        on_delete: :delete,
        match_with: [group_id: :group_id]
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :tag_id,
        :taggable_type,
        :taggable_id,
        :tagged_by_group_user_relation_id,
        :dimensions,
        :description
      ]

      change SetGroupFromCurrentTenant
      change ValidateTarget
      change NormalizeMembershipFields
    end

    update :update_details do
      accept [:dimensions, :description]
      require_atomic? false

      change NormalizeMembershipFields
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if Group.Checks.ActorIsMemberOfResourceGroup
    end

    policy action(:create) do
      authorize_if ActorCanManageOwnMembershipTagging
    end

    policy action(:update_details) do
      authorize_if ActorCanManageOwnMembershipTagging
    end

    policy action_type(:destroy) do
      authorize_if ActorCanManageOwnMembershipTagging
    end
  end

  pub_sub do
    module WikWeb.Endpoint
    prefix "tagging"
    publish :create, [:taggable_type, :taggable_id]
    publish :update_details, [:taggable_type, :taggable_id]
    publish :destroy, [:taggable_type, :taggable_id]
    publish :create, ["group", :group_id]
    publish :update_details, ["group", :group_id]
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

    attribute :taggable_type, :string do
      public? true
      allow_nil? false
      constraints min_length: 1
    end

    attribute :taggable_id, :uuid do
      public? true
      allow_nil? false
    end

    attribute :dimensions, :map do
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

    belongs_to :tag, Tag do
      destination_attribute :id
      allow_nil? false
    end

    belongs_to :tagged_by_group_user_relation, GroupUserRelation do
      destination_attribute :id
      allow_nil? false
    end
  end

  identities do
    identity :unique_group_target_author_tag,
             [
               :group_id,
               :taggable_type,
               :taggable_id,
               :tagged_by_group_user_relation_id,
               :tag_id
             ]
  end

  def group_pub_sub_topic(group_id), do: "tagging:group:#{group_id}"

  def target_pub_sub_topic(taggable_type, taggable_id),
    do: "tagging:#{taggable_type}:#{taggable_id}"
end
