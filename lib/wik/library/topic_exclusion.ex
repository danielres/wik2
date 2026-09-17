defmodule Wik.Library.TopicExclusion do
  alias Wik.Accounts.Space
  alias Wik.Changes.SetSpaceFromCurrentTenant
  alias Wik.Library.Entry
  alias Wik.Tags.Tag

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Library,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  postgres do
    table "library_topic_exclusions"
    repo Wik.Repo

    references do
      reference :entry, on_delete: :delete, match_with: [space_id: :space_id]
      reference :space, on_delete: :delete
      reference :tag, on_delete: :delete, match_with: [space_id: :space_id]
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:entry_id, :tag_id]
      change SetSpaceFromCurrentTenant
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin), do: authorize_if(always())

    policy action_type(:read), do: authorize_if(Space.Checks.ActorIsMemberOfResourceSpace)
    policy action_type(:create), do: authorize_if(Space.Checks.ActorIsMemberOfCurrentTenantSpace)
    policy action_type(:destroy), do: authorize_if(Space.Checks.ActorIsMemberOfResourceSpace)
  end

  multitenancy do
    strategy :attribute
    attribute :space_id
    parse_attribute {Wik.Accounts, :tenant_to_space_id, []}
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()
  end

  relationships do
    belongs_to :entry, Entry, do: allow_nil?(false)
    belongs_to :space, Space, do: allow_nil?(false)
    belongs_to :tag, Tag, do: allow_nil?(false)
  end

  identities do
    identity :unique_entry_tag, [:entry_id, :tag_id]
  end
end
