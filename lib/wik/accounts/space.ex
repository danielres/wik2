defmodule Wik.Accounts.Space do
  alias Wik.Access.Source
  alias Wik.Accounts.Space.Changes
  alias Wik.Accounts.Space.Checks
  alias Wik.Events.ExternalCalendarSubscription
  alias Wik.Events.EventPublication
  alias Wik.Accounts.User
  alias Wik.Accounts.Membership

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource],
    authorizers: [Ash.Policy.Authorizer]

  defimpl Ash.ToTenant do
    def to_tenant(%{slug: slug}, _resource), do: slug
  end

  postgres do
    table "spaces"
    repo Wik.Repo
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
      accept [:name, :slug, :description]
      change Changes.CreateWithOwnerMembership
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if Checks.ActorIsMemberOfSpace
    end

    policy action_type(:create) do
      authorize_if Checks.ActorHasOwnerSpaceMembership
      authorize_if Checks.ActorHasAdminSpaceMembership
    end

    # TODO: consider only allowing updates by owner
    policy action_type(:update) do
      authorize_if Checks.ActorCanManageSpace
    end
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :slug, Wik.Types.Slug do
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

    has_many :memberships, Membership do
      destination_attribute :space_id
      default_sort type_sort: :asc, inserted_at: :asc
    end

    has_many :access_sources, Source do
      destination_attribute :space_id
    end

    has_many :event_publications, EventPublication do
      source_attribute :id
      destination_attribute :target_space_id
    end

    has_many :external_calendar_subscriptions, ExternalCalendarSubscription do
      destination_attribute :space_id
    end

    many_to_many :users, User do
      through Membership
      source_attribute_on_join_resource :space_id
      destination_attribute_on_join_resource :user_id
    end
  end

  identities do
    identity :unique_slug, :slug
  end
end

defimpl String.Chars, for: Wik.Accounts.Space do
  def to_string(%Wik.Accounts.Space{name: name}), do: name
end
