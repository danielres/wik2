defmodule Wik.Accounts.Membership do
  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource],
    notifiers: [Ash.Notifier.PubSub, Wik.Activity.Notifier]

  alias Wik.Accounts.Space
  alias Wik.Accounts.Membership.Checks
  alias Wik.Accounts.Membership.Changes
  alias Wik.Accounts.Membership.Validations.PrimaryBlock
  alias Wik.Blocks.Block

  postgres do
    table "memberships"
    repo Wik.Repo
  end

  admin do
    table_columns [:space, :user, :type, :inserted_at]

    format_fields inserted_at: {Calendar, :strftime, ["%Y-%m-%d %H:%M"]}
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:space_id, :user_id, :type]
    end

    update :set_type do
      accept [:type]
      public? false
      require_atomic? false
    end

    update :update_membership_type do
      accept [:type]
      public? false
      require_atomic? false

      validate attribute_does_not_equal(:type, :owner)
    end

    update :transfer_ownership do
      require_atomic? false

      argument :target_membership_id, :uuid do
        allow_nil? false
      end

      change Wik.Accounts.Membership.Changes.TransferOwnership
    end

    update :set_username do
      accept [:username]
      require_atomic? false

      change Changes.SetUsername
    end

    update :set_primary_block do
      accept [:primary_block_id]
      require_atomic? false
    end

    update :mark_seen do
      accept []
      public? false
      require_atomic? false
      change set_attribute(:last_seen_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :superadmin)
      authorize_if Space.Checks.ActorIsMemberOfResourceSpace
    end

    policy action(:update_membership_type) do
      authorize_if expr(type != :owner and ^actor(:role) == :superadmin)
      authorize_if Checks.ActorCanUpdateMembershipType
    end

    policy action(:transfer_ownership) do
      authorize_if expr(type == :owner and ^actor(:role) == :superadmin)
      authorize_if expr(type == :owner and user_id == ^actor(:id))
    end

    policy action(:set_username) do
      authorize_if actor_attribute_equals(:role, :superadmin)
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action(:set_primary_block) do
      authorize_if actor_attribute_equals(:role, :superadmin)
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action_type(:create) do
      authorize_if actor_attribute_equals(:role, :superadmin)
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :superadmin)
    end
  end

  pub_sub do
    module WikWeb.Endpoint
    prefix "membership"
    publish :set_username, ["space", :space_id]
    publish :set_username, ["user", :user_id]
    publish :update_membership_type, ["space", :space_id]
    publish :update_membership_type, ["user", :user_id]
    publish :mark_seen, ["space", :space_id]
  end

  validations do
    validate PrimaryBlock
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :space_id, :uuid do
      source :space_id
      public? true
      allow_nil? false
    end

    attribute :type, :atom do
      constraints one_of: [:owner, :admin, :member]
      public? true
      allow_nil? false
      default :member
    end

    attribute :username, Wik.Types.Slug do
      public? true
    end

    attribute :last_seen_at, :utc_datetime_usec do
      public? true
    end
  end

  relationships do
    belongs_to :space, Wik.Accounts.Space do
      define_attribute? false
      allow_nil? false
    end

    belongs_to :user, Wik.Accounts.User do
      allow_nil? false
    end

    belongs_to :primary_block, Block do
      destination_attribute :id
      allow_nil? true
      public? true
    end
  end

  calculations do
    calculate :avatar_url, :string, Wik.Accounts.Membership.Calculations.AvatarUrl do
      public? true
      filterable? false
      sortable? false
    end

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
    identity :unique_membership, [:space_id, :user_id]
    identity :unique_space_username, [:space_id, :username]
    identity :unique_space_scoped_id, [:id, :space_id]
  end

  def updatable_types do
    __MODULE__
    |> Ash.Resource.Info.attribute(:type)
    |> then(& &1.constraints[:one_of])
    |> Enum.reject(&(&1 == :owner))
  end

  def space_pub_sub_topic(space_id), do: "membership:space:#{space_id}"
  def user_pub_sub_topic(user_id), do: "membership:user:#{user_id}"
end
