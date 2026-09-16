defmodule Wik.Library.TopicRule do
  alias Wik.Accounts.Space
  alias Wik.Changes.SetSpaceFromCurrentTenant
  alias Wik.Tags.Tag

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Library,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  postgres do
    table "library_topic_rules"
    repo Wik.Repo

    references do
      reference :space, on_delete: :delete
      reference :tag, on_delete: :delete, match_with: [space_id: :space_id]
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:aliases, :enabled, :tag_id]
      change SetSpaceFromCurrentTenant
    end

    update :update do
      accept [:aliases, :enabled]
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin), do: authorize_if(always())

    policy action_type(:read), do: authorize_if(Space.Checks.ActorIsMemberOfResourceSpace)
    policy action_type(:create), do: authorize_if(Space.Checks.ActorCanManageCurrentTenantSpace)
    policy action_type(:update), do: authorize_if(Space.Checks.ActorCanManageResourceSpace)
    policy action_type(:destroy), do: authorize_if(Space.Checks.ActorCanManageResourceSpace)
  end

  multitenancy do
    strategy :attribute
    attribute :space_id
    parse_attribute {Wik.Accounts, :tenant_to_space_id, []}
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :aliases, {:array, :string} do
      public? true
      allow_nil? false
      default []
    end

    attribute :enabled, :boolean do
      public? true
      allow_nil? false
      default true
    end
  end

  relationships do
    belongs_to :space, Space, do: allow_nil?(false)
    belongs_to :tag, Tag, do: allow_nil?(false)
  end

  identities do
    identity :unique_space_tag, [:space_id, :tag_id]
  end
end
