defmodule Qblog.Accounts.GroupUserRelation do
  use Ash.Resource,
    otp_app: :qblog,
    domain: Qblog.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "group_user_relations"
    repo Qblog.Repo
  end

  actions do
    defaults [:create, :read, :destroy]
  end

  policies do
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :superadmin)
    end

    policy action_type(:create) do
      authorize_if actor_attribute_equals(:role, :superadmin)
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :superadmin)
    end
  end

  attributes do
    timestamps()
  end

  relationships do
    belongs_to :group, Qblog.Accounts.Group do
      primary_key? true
      allow_nil? false
    end

    belongs_to :user, Qblog.Accounts.User do
      primary_key? true
      allow_nil? false
    end
  end

  identities do
    identity :unique_group_user_relation, [:group_id, :user_id]
  end
end

