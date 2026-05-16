defmodule Wik.Tickets.Ticket do
  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Tickets,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  postgres do
    table "tickets"
    repo Wik.Repo
  end

  admin do
    table_columns [:type, :status, :submitted_by, :handled_by, :inserted_at]

    format_fields inserted_at: {Calendar, :strftime, ["%Y-%m-%d %H:%M"]}
  end

  actions do
    defaults [:read]

    create :submit do
      accept [:app_path, :body, :subject, :type]

      change relate_actor(:submitted_by, allow_nil?: false)
    end

    update :triage do
      accept [:admin_notes, :handled_at, :status]
      require_atomic? false
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin) do
      authorize_if always()
    end

    policy action(:submit) do
      authorize_if actor_present()
    end

    policy action_type(:read) do
      authorize_if expr(submitted_by_id == ^actor(:id))
    end

    policy action(:triage) do
      authorize_if actor_attribute_equals(:role, :superadmin)
    end
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :type, :atom do
      constraints one_of: [:feedback, :privacy_request, :moderation_report]
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:new, :in_progress, :closed]
      allow_nil? false
      default :new
      public? true
    end

    attribute :subject, :string do
      allow_nil? false
      public? true
    end

    attribute :body, :string do
      allow_nil? false
      public? true
    end

    attribute :admin_notes, :string do
      allow_nil? true
      public? true
    end

    attribute :app_path, :string do
      allow_nil? false
      public? true
    end

    attribute :handled_at, :utc_datetime_usec do
      allow_nil? true
      public? true
    end
  end

  relationships do
    belongs_to :submitted_by, Wik.Accounts.User do
      allow_nil? false
    end

    belongs_to :handled_by, Wik.Accounts.User do
      allow_nil? true
    end
  end
end
