defmodule Qblog.Accounts.Group do
  alias Qblog.Accounts.Group.Changes
  alias Qblog.Accounts.Group.Checks
  alias Qblog.Accounts.User
  alias Qblog.Accounts.GroupUserRelation

  use Ash.Resource,
    otp_app: :qblog,
    domain: Qblog.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource],
    authorizers: [Ash.Policy.Authorizer]

  defimpl Ash.ToTenant do
    def to_tenant(%{name: name}, _resource), do: name
  end

  postgres do
    table "groups"
    repo Qblog.Repo
  end

  admin do
    label_field :name
    relationship_display_fields [:name]
  end

  actions do
    defaults [
      :read,
      :destroy,
      update: :*
    ]

    create :create do
      accept [:name, :description]
      change Changes.CreateWithOwnerMembership
    end
  end

  policies do
    policy action_type(:read) do
      # authorize_if relates_to_actor_via(:owner)
      authorize_if relates_to_actor_via(:users)
      authorize_if actor_attribute_equals(:role, :superadmin)
    end

    policy action_type(:create) do
      authorize_if actor_attribute_equals(:role, :superadmin)
      authorize_if Checks.ActorHasAnyGroupMembership
    end

    policy action_type(:update) do
      authorize_if expr(exists(memberships, user_id == ^actor(:id) and type in [:owner, :admin]))
      authorize_if actor_attribute_equals(:role, :superadmin)
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :superadmin)
    end
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :description, :string do
      public? true
      allow_nil? true
    end
  end

  relationships do
    belongs_to :author, User do
      destination_attribute :id
      allow_nil? false
    end

    has_many :memberships, GroupUserRelation do
      destination_attribute :group_id
      default_sort type_sort: :asc, inserted_at: :asc
    end

    many_to_many :users, User do
      through GroupUserRelation
      source_attribute_on_join_resource :group_id
      destination_attribute_on_join_resource :user_id
    end
  end

  identities do
    identity :unique_name, :name
  end
end

defimpl String.Chars, for: Qblog.Accounts.Group do
  def to_string(%Qblog.Accounts.Group{name: name}), do: name
end
