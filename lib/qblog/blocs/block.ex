defmodule Qblog.Blocs.Block do
  use Ash.Resource,
    otp_app: :qblog,
    domain: Qblog.Blocs,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  postgres do
    table "blocks"
    repo Qblog.Repo
  end

  admin do
    label_field :type
  end

  actions do
    defaults [
      :read,
      :update,
      :destroy
    ]

    create :create do
      accept [:data, :type]
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

    attribute :type, :atom do
      constraints one_of: [:text]
      public? true
      allow_nil? false
    end

    attribute :data, :map do
      public? true
      allow_nil? false
      default %{}
    end
  end

  relationships do
    has_many :placements, Qblog.Blocs.BlockPlacement do
      destination_attribute :block_id
      default_sort order_key: :asc
    end
  end
end
