defmodule Qblog.Blocks.BlockPlacement do
  use Ash.Resource,
    otp_app: :qblog,
    domain: Qblog.Blocks,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  postgres do
    table "block_placements"
    repo Qblog.Repo
  end

  actions do
    defaults [
      :read,
      :update,
      :destroy
    ]

    create :create do
      accept [:attachable_id, :attachable_type, :block_id, :order_key]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type(:create) do
      authorize_if always()
    end

    policy action_type(:update) do
      authorize_if always()
    end

    policy action_type(:destroy) do
      authorize_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :attachable_type, :string do
      public? true
      allow_nil? false
    end

    attribute :attachable_id, :uuid do
      public? true
      allow_nil? false
    end

    attribute :order_key, :string do
      public? true
      allow_nil? false
    end
  end

  relationships do
    belongs_to :block, Qblog.Blocks.Block do
      allow_nil? false
    end
  end

  identities do
    identity :unique_attachable_order_key, [:attachable_type, :attachable_id, :order_key] do
      eager_check? true
    end
  end
end
