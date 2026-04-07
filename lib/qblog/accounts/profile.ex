defmodule Qblog.Accounts.Profile do
  use Ash.Resource,
    otp_app: :qblog,
    domain: Qblog.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  postgres do
    table "profiles"
    repo Qblog.Repo
  end

  admin do
    table_columns [:group_user_relation, :inserted_at]

    format_fields inserted_at: {Calendar, :strftime, ["%Y-%m-%d %H:%M"]}
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:group_user_relation_id]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :superadmin)
      authorize_if relates_to_actor_via([:group_user_relation, :group, :users])
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
    belongs_to :group_user_relation, Qblog.Accounts.GroupUserRelation do
      allow_nil? false
    end

    has_many :block_placements, Qblog.Blocks.BlockPlacement do
      source_attribute :id
      destination_attribute :attachable_id
      filter expr(attachable_type == "profile" and attachable_id == parent(id))
      default_sort order_key: :asc
    end

    many_to_many :blocks, Qblog.Blocks.Block do
      through Qblog.Blocks.BlockPlacement
      source_attribute_on_join_resource :attachable_id
      destination_attribute_on_join_resource :block_id
      filter expr(attachable_type == "profile")
    end
  end

  identities do
    identity :unique_group_user_relation_profile, [:group_user_relation_id]
  end
end
