defmodule Wik.Blocks.Block do
  alias Wik.Accounts.Space
  alias Wik.Accounts.User
  alias Wik.Blocks.Block.Checks
  alias Wik.Blocks.Block.Validations.DataMatchesType
  alias Wik.Blocks.Block.Validations.ExactlyOneOwner
  alias Wik.Blocks.Types

  @supported_types Types.available() |> Enum.map(& &1.type)

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Blocks,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "blocks"
    repo Wik.Repo
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
      accept [:data, :owner_space_id, :owner_user_id, :type]
      change relate_actor(:author, allow_nil?: false)
    end

    update :update do
      accept [:data, :owner_space_id, :owner_user_id, :type]
      require_atomic? false
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin), do: authorize_if(always())

    policy action_type(:read) do
      authorize_if relates_to_actor_via(:owner_user)
      authorize_if Checks.ActorCanReadSpaceOwnedBlock
      authorize_if Checks.ActorCanReadPlacedBlock
    end

    policy action_type(:create) do
      authorize_if relating_to_actor(:owner_user)
      authorize_if Checks.ActorCanCreateCurrentTenantSpaceOwnedBlock
    end

    policy action_type(:update) do
      authorize_if relates_to_actor_via(:owner_user)
      authorize_if Checks.ActorCanManageSpaceOwnedBlock
    end

    policy action_type(:destroy) do
      authorize_if relates_to_actor_via(:owner_user)
      authorize_if Checks.ActorCanManageSpaceOwnedBlock
    end
  end

  pub_sub do
    module WikWeb.Endpoint
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

    belongs_to :owner_space, Space do
      destination_attribute :id
      allow_nil? true
    end

    belongs_to :owner_user, User do
      destination_attribute :id
      allow_nil? true
    end

    has_many :placements, Wik.Blocks.BlockPlacement do
      destination_attribute :block_id
      default_sort order_key: :asc
    end

    has_many :versions, Wik.Blocks.BlockVersion do
      destination_attribute :block_id
      default_sort revision: :desc
    end
  end
end
