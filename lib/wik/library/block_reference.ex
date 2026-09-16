defmodule Wik.Library.BlockReference do
  alias Wik.Accounts.Space
  alias Wik.Blocks.Block
  alias Wik.Changes.SetSpaceFromCurrentTenant
  alias Wik.Library.Entry

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Library,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "library_block_references"
    repo Wik.Repo

    references do
      reference :block, on_delete: :delete
      reference :entry, on_delete: :restrict, match_with: [space_id: :space_id]
      reference :space, on_delete: :delete
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:block_id, :entry_id]
      change SetSpaceFromCurrentTenant
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin), do: authorize_if(always())

    policy action_type(:read), do: authorize_if(Space.Checks.ActorIsMemberOfResourceSpace)
    policy action_type(:create), do: authorize_if(Space.Checks.ActorCanManageCurrentTenantSpace)
  end

  pub_sub do
    module WikWeb.Endpoint
    prefix "block"
    publish :create, [:block_id]
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
    belongs_to :block, Block, do: allow_nil?(false)
    belongs_to :entry, Entry, do: allow_nil?(false)
    belongs_to :space, Space, do: allow_nil?(false)
  end

  identities do
    identity :unique_block, :block_id
    identity :unique_space_scoped_id, [:id, :space_id]
  end
end
