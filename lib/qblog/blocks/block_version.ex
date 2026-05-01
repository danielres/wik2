defmodule Qblog.Blocks.BlockVersion do
  alias Qblog.Accounts.User
  alias Qblog.Blocks.Block
  alias Qblog.Blocks.BlockVersion.Checks
  alias Qblog.Blocks.BlockVersion.Validations.StorageMatchesKind

  use Ash.Resource,
    otp_app: :qblog,
    domain: Qblog.Blocks,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  postgres do
    table "block_versions"
    repo Qblog.Repo
  end

  admin do
    label_field :revision
  end

  actions do
    defaults [:read]

    create :create do
      accept [:block_id, :block_type, :diff_data, :revision, :snapshot_text, :storage_kind]
      change relate_actor(:author, allow_nil?: false)
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if Checks.ActorCanReadResourceBlock
    end
  end

  validations do
    validate StorageMatchesKind
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :block_type, :atom do
      constraints one_of: [:markdown]
      public? true
      allow_nil? false
    end

    attribute :diff_data, :map do
      public? true
      allow_nil? true
    end

    attribute :revision, :integer do
      public? true
      allow_nil? false
      constraints min: 1
    end

    attribute :snapshot_text, :string do
      public? true
      allow_nil? true
    end

    attribute :storage_kind, :atom do
      constraints one_of: [:snapshot, :line_diff]
      public? true
      allow_nil? false
    end
  end

  relationships do
    belongs_to :author, User do
      destination_attribute :id
      allow_nil? false
    end

    belongs_to :block, Block do
      destination_attribute :id
      allow_nil? false
    end
  end

  identities do
    identity :unique_block_revision, [:block_id, :revision] do
      eager_check? true
    end
  end
end
