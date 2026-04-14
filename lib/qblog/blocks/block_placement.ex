defmodule Qblog.Blocks.BlockPlacement do
  alias Qblog.Accounts.Group
  alias Qblog.Blocks.BlockPlacement.Checks
  alias Qblog.Blocks.BlockPlacement.Changes

  use Ash.Resource,
    otp_app: :qblog,
    domain: Qblog.Blocks,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "block_placements"
    repo Qblog.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:attachable_id, :attachable_type, :block_id, :order_key, :width]
      change Changes.SetGroupFromAttachable
    end

    update :update_order, do: accept([:order_key])
    update :update_width, do: accept([:width])
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if Group.Checks.ActorIsMemberOfResourceGroup
    end

    policy action_type(:create) do
      authorize_if Checks.ActorCanCreateCurrentTenantPagePlacement
    end

    policy action_type(:destroy) do
      authorize_if Group.Checks.ActorCanManageResourceGroup
    end

    policy action(:update_order) do
      authorize_if Group.Checks.ActorCanManageResourceGroup
    end

    policy action(:update_width) do
      authorize_if Group.Checks.ActorCanManageResourceGroup
    end
  end

  pub_sub do
    module QblogWeb.Endpoint
    prefix "block_placement"
    publish :create, [:attachable_type, :attachable_id]
    publish :update_order, [:attachable_type, :attachable_id]
    publish :update_width, [:attachable_type, :attachable_id]
    publish :destroy, [:attachable_type, :attachable_id]
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :attachable_id, :uuid do
      public? true
      allow_nil? false
    end

    attribute :attachable_type, :string do
      public? true
      allow_nil? false
    end

    attribute :order_key, :string do
      public? true
      allow_nil? false
    end

    attribute :width, :string do
      public? true
      allow_nil? false
      constraints match: ~r/^(full|half)$/
      default "full"
    end
  end

  relationships do
    belongs_to :block, Qblog.Blocks.Block, do: allow_nil?(false)
    belongs_to :group, Group, do: allow_nil?(false)
  end

  identities do
    identity :unique_attachable_order_key, [:attachable_type, :attachable_id, :order_key] do
      eager_check? true
    end
  end
end
