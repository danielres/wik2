defmodule Qblog.Wiki.Page do
  alias Qblog.Accounts.Group

  use Ash.Resource,
    otp_app: :qblog,
    domain: Qblog.Wiki,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshPhoenix]

  postgres do
    table "pages"
    repo Qblog.Repo
  end

  code_interface do
    define :get_by_id, action: :read, get_by: [:id]
    define :create, action: :create, args: []
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

  multitenancy do
    strategy :attribute
    attribute :group_id
    parse_attribute {Qblog.Accounts, :group_name_to_id, []}
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()
  end

  relationships do
    belongs_to :group, Qblog.Accounts.Group do
      destination_attribute :id
      allow_nil? false
    end

    belongs_to :author, Qblog.Accounts.User do
      destination_attribute :id
      allow_nil? false
    end

    has_many :block_placements, Qblog.Blocks.BlockPlacement do
      source_attribute :id
      destination_attribute :attachable_id
      filter expr(attachable_type == "page" and attachable_id == parent(id))
      default_sort order_key: :asc
    end

    many_to_many :blocks, Qblog.Blocks.Block do
      through Qblog.Blocks.BlockPlacement
      source_attribute_on_join_resource :attachable_id
      destination_attribute_on_join_resource :block_id
      filter expr(attachable_type == "page")
    end
  end
end
