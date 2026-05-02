defmodule Qblog.Accounts.GroupUserRelation do
  use Ash.Resource,
    otp_app: :qblog,
    domain: Qblog.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource],
    notifiers: [Ash.Notifier.PubSub]

  alias Qblog.Accounts.Group

  postgres do
    table "group_user_relations"
    repo Qblog.Repo
  end

  admin do
    table_columns [:group, :user, :type, :inserted_at]

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

      change Qblog.Accounts.GroupUserRelation.Changes.TransferOwnership
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :superadmin)
      authorize_if Group.Checks.ActorIsMemberOfResourceGroup
    end

    policy action(:update) do
      authorize_if expr(type != :owner and ^actor(:role) == :superadmin)

      authorize_if expr(
                     type != :owner and user_id != ^actor(:id) and
                       exists(group.memberships, user_id == ^actor(:id) and type == :owner)
                   )
    end

    policy action(:transfer_ownership) do
      authorize_if expr(type == :owner and ^actor(:role) == :superadmin)
      authorize_if expr(type == :owner and user_id == ^actor(:id))
    end

    policy action_type(:create) do
      authorize_if actor_attribute_equals(:role, :superadmin)
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :superadmin)
    end
  end

  pub_sub do
    module QblogWeb.Endpoint
    prefix "group_user_relation"
    publish :update, ["group", :group_id]
    publish :update, ["user", :user_id]
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

    has_one :profile, Qblog.Accounts.Profile do
      destination_attribute :group_user_relation_id
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

  def updatable_types do
    __MODULE__
    |> Ash.Resource.Info.attribute(:type)
    |> then(& &1.constraints[:one_of])
    |> Enum.reject(&(&1 == :owner))
  end

  def group_pub_sub_topic(group_id), do: "group_user_relation:group:#{group_id}"
  def user_pub_sub_topic(user_id), do: "group_user_relation:user:#{user_id}"
end
