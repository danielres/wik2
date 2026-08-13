defmodule Wik.Activity.Entry do
  alias Wik.Accounts.Membership
  alias Wik.Accounts.Space

  @categories [:wiki, :topics, :events, :members, :other]
  @kinds [
    :event_cancelled,
    :event_created,
    :event_participation_changed,
    :event_participation_removed,
    :event_relayed,
    :event_updated,
    :member_joined,
    :member_left,
    :member_profile_updated,
    :member_role_changed,
    :member_tag_added,
    :member_tag_removed,
    :member_tag_updated,
    :page_created,
    :page_deleted,
    :page_updated,
    :space_created,
    :space_updated,
    :topic_created,
    :topic_deleted,
    :topic_updated
  ]
  @subject_types [:event, :member, :page, :space, :topic]

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Activity,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "activity_entries"
    repo Wik.Repo

    references do
      reference :actor_membership, on_delete: :nilify
    end

    custom_indexes do
      index [:space_id, :occurred_at]
      index [:space_id, :category, :occurred_at]
      index [:space_id, :collapse_key, :occurred_at]
    end
  end

  admin do
    table_columns [:category, :kind, :actor_label, :subject_label, :occurred_at]
  end

  actions do
    defaults [:read]

    read :aggregate do
      multitenancy :bypass
    end

    create :record do
      accept [
        :actor_label,
        :actor_membership_id,
        :actor_username,
        :category,
        :collapse_key,
        :kind,
        :metadata,
        :occurred_at,
        :occurrence_count,
        :space_id,
        :subject_id,
        :subject_label,
        :subject_path,
        :subject_type
      ]

      primary? true
    end

    update :collapse do
      accept [
        :actor_label,
        :actor_membership_id,
        :actor_username,
        :kind,
        :metadata,
        :occurred_at,
        :occurrence_count,
        :subject_label,
        :subject_path
      ]

      require_atomic? false
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if Space.Checks.ActorIsMemberOfResourceSpace
    end

    policy action_type(:create) do
      authorize_if always()
    end

    policy action_type(:update) do
      authorize_if always()
    end
  end

  pub_sub do
    module WikWeb.Endpoint
    prefix "activity_entry"
    publish :record, ["space", :space_id]
    publish :collapse, ["space", :space_id]
  end

  multitenancy do
    strategy :attribute
    attribute :space_id
    parse_attribute {Wik.Accounts, :tenant_to_space_id, []}
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :category, :atom do
      constraints one_of: @categories
      allow_nil? false
      public? true
    end

    attribute :kind, :atom do
      constraints one_of: @kinds
      allow_nil? false
      public? true
    end

    attribute :subject_type, :atom do
      constraints one_of: @subject_types
      allow_nil? false
      public? true
    end

    attribute :subject_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :subject_label, :string do
      allow_nil? false
      public? true
    end

    attribute :subject_path, :string do
      public? true
    end

    attribute :actor_label, :string do
      public? true
    end

    attribute :actor_username, :string do
      public? true
    end

    attribute :metadata, :map do
      allow_nil? false
      default %{}
      public? true
    end

    attribute :occurrence_count, :integer do
      constraints min: 1
      allow_nil? false
      default 1
      public? true
    end

    attribute :occurred_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :collapse_key, :string do
      public? false
    end
  end

  relationships do
    belongs_to :space, Space do
      destination_attribute :id
      allow_nil? false
    end

    belongs_to :actor_membership, Membership do
      destination_attribute :id
      allow_nil? true
    end
  end

  calculations do
    calculate :event_starts_at,
              :utc_datetime_usec,
              Wik.Activity.Entry.Calculations.EventStartsAt do
      public? true
      filterable? false
      sortable? false
    end
  end

  def space_pub_sub_topic(space_id), do: "activity_entry:space:#{space_id}"
end
