defmodule Qblog.Blocks.Block do
  alias Qblog.Accounts.Group
  alias Qblog.Accounts.User
  alias Qblog.Blocks.Block.Validations.DataMatchesType
  alias Qblog.Blocks.Block.Validations.ExactlyOneOwner
  alias Qblog.Blocks.Types

  @supported_types Types.available() |> Enum.map(& &1.type)

  use Ash.Resource,
    otp_app: :qblog,
    domain: Qblog.Blocks,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "blocks"
    repo Qblog.Repo
  end

  admin do
    label_field :type
  end

  code_interface do
    define :get_by_id, action: :read, get_by: [:id]
  end

  actions do
    defaults [
      :read,
      :destroy
    ]

    create :create do
      accept [:data, :owner_group_id, :owner_user_id, :type]
      change relate_actor(:author, allow_nil?: false)
    end

    update :update do
      accept [:data, :owner_group_id, :owner_user_id]
      require_atomic? false
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

  pub_sub do
    module QblogWeb.Endpoint
    prefix "block"
    publish :update, [:id]
  end

  validations do
    validate DataMatchesType
    validate ExactlyOneOwner
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :type, :atom do
      constraints one_of: @supported_types
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
    belongs_to :author, User do
      destination_attribute :id
      allow_nil? false
    end

    belongs_to :owner_group, Group do
      destination_attribute :id
      allow_nil? true
    end

    belongs_to :owner_user, User do
      destination_attribute :id
      allow_nil? true
    end

    has_many :placements, Qblog.Blocks.BlockPlacement do
      destination_attribute :block_id
      default_sort order_key: :asc
    end
  end
end
