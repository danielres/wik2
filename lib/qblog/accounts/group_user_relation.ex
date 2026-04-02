defmodule Qblog.Accounts.GroupUserRelation do
  use Ash.Resource,
    otp_app: :qblog,
    domain: Qblog.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  postgres do
    table "group_user_relations"
    repo Qblog.Repo
  end

  admin do
    table_columns [:group, :user, :inserted_at]

    format_fields inserted_at: {Calendar, :strftime, ["%Y-%m-%d %H:%M"]}
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:group_id, :user_id, :type]
    end

    update :update do
      accept [:type]
      public? false
    end

    update :transfer_ownership do
      require_atomic? false

      argument :target_membership_id, :uuid do
        allow_nil? false
      end

      change Qblog.Changes.GroupUserRelationTransferOwnership
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :superadmin)
      authorize_if relates_to_actor_via([:group, :users])
    end

    policy action(:transfer_ownership) do
      forbid_unless expr(type == :owner)
      authorize_if actor_attribute_equals(:role, :superadmin)
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action_type(:create) do
      # TODO: allow group owners to invite users to their groups
      authorize_if actor_attribute_equals(:role, :superadmin)
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :superadmin)
    end
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :type, :atom do
      constraints one_of: [:owner, :admin, :member]
      public? true
      allow_nil? false
      default :member
    end
  end

  relationships do
    belongs_to :group, Qblog.Accounts.Group do
      allow_nil? false
    end

    belongs_to :user, Qblog.Accounts.User do
      allow_nil? false
    end
  end

  calculations do
    calculate :type_sort,
              :integer,
              expr(
                fragment(
                  "CASE WHEN ? = 'owner' THEN 0 WHEN ? = 'admin' THEN 1 ELSE 2 END",
                  type,
                  type
                )
              )
  end

  identities do
    identity :unique_group_user_relation, [:group_id, :user_id]
  end
end
