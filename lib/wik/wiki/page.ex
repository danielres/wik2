defmodule Wik.Wiki.Page do
  alias Wik.Accounts.Group

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Wiki,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshPhoenix],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "pages"
    repo Wik.Repo
  end

  code_interface do
    define :get_by_id, action: :read, get_by: [:id]
    define :create, action: :create, args: []

    # Used for authorization semantics with Ash.can?(), not for mutating data
    define :manage_page, action: :manage_page, args: []
  end

  actions do
    defaults [
      :read,
      :update,
      :destroy
    ]

    create :create do
      change relate_actor(:author, allow_nil?: false)
    end

    update :manage_page, do: require_atomic?(false)
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

    policy action(:manage_page) do
      authorize_if Group.Checks.ActorCanManageResourceGroup
    end
  end

  pub_sub do
    module WikWeb.Endpoint
    prefix "page"
    publish :create, ["group", :group_id]
    publish :update, ["group", :group_id]
    publish :destroy, ["group", :group_id]
  end

  multitenancy do
    strategy :attribute
    attribute :group_id
    parse_attribute {Wik.Accounts, :group_name_to_id, []}
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

    belongs_to :author, Wik.Accounts.User do
      destination_attribute :id
      allow_nil? false
    end

    has_many :block_placements, Wik.Blocks.BlockPlacement do
      source_attribute :id
      destination_attribute :attachable_id
      filter expr(attachable_type == "page" and attachable_id == parent(id))
      default_sort order_key: :asc
    end

    many_to_many :blocks, Wik.Blocks.Block do
      through Wik.Blocks.BlockPlacement
      source_attribute_on_join_resource :attachable_id
      destination_attribute_on_join_resource :block_id
      filter expr(attachable_type == "page")
    end
  end
end
