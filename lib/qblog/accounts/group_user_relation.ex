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
  end

  policies do
    policy action_type(:read) do
      # TODO: allow group owners and members to read the relations
      authorize_if actor_attribute_equals(:role, :superadmin)
      authorize_if relates_to_actor_via([:group, :users])
      # authorize_if relates_to_actor_via([:group, :owner])
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

  identities do
    identity :unique_group_user_relation, [:group_id, :user_id]
  end
end
