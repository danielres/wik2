defmodule Wik.Library.Settings do
  alias Wik.Accounts.Space
  alias Wik.Changes.SetSpaceFromCurrentTenant

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Library,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  postgres do
    table "library_settings"
    repo Wik.Repo

    references do
      reference :space, on_delete: :delete
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:automatic_topic_matching]
      change SetSpaceFromCurrentTenant
    end

    update :update do
      accept [:automatic_topic_matching]
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin), do: authorize_if(always())

    policy action_type(:read), do: authorize_if(Space.Checks.ActorIsMemberOfResourceSpace)
    policy action_type(:create), do: authorize_if(Space.Checks.ActorCanManageCurrentTenantSpace)
    policy action_type(:update), do: authorize_if(Space.Checks.ActorCanManageResourceSpace)
  end

  multitenancy do
    strategy :attribute
    attribute :space_id
    parse_attribute {Wik.Accounts, :tenant_to_space_id, []}
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :automatic_topic_matching, :boolean do
      public? true
      allow_nil? false
      default true
    end
  end

  relationships do
    belongs_to :space, Space, do: allow_nil?(false)
  end

  identities do
    identity :unique_space, :space_id
  end
end
