defmodule Wik.Accounts.Profile do
  alias Wik.Accounts.Profile.Checks.ActorCanReadProfile

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  postgres do
    table "profiles"
    repo Wik.Repo
  end

  admin do
    table_columns [:membership, :inserted_at]

    format_fields inserted_at: {Calendar, :strftime, ["%Y-%m-%d %H:%M"]}
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:membership_id]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :superadmin)
      authorize_if ActorCanReadProfile
    end

    policy action_type(:create) do
      authorize_if actor_attribute_equals(:role, :superadmin)
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :superadmin)
    end
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()
  end

  relationships do
    belongs_to :membership, Wik.Accounts.Membership do
      allow_nil? false
    end

    has_many :block_placements, Wik.Blocks.BlockPlacement do
      source_attribute :id
      destination_attribute :attachable_id
      filter expr(attachable_type == "profile" and attachable_id == parent(id))
      default_sort order_key: :asc
    end

    many_to_many :blocks, Wik.Blocks.Block do
      through Wik.Blocks.BlockPlacement
      source_attribute_on_join_resource :attachable_id
      destination_attribute_on_join_resource :block_id
      filter expr(attachable_type == "profile")
    end
  end

  identities do
    identity :unique_membership_profile, [:membership_id]
  end
end
