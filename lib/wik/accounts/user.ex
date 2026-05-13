defmodule Wik.Accounts.User do
  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication, AshAdmin.Resource]

  alias Wik.Accounts.Group
  alias Wik.Accounts.GroupUserRelation
  alias Wik.Accounts.User.Changes
  alias Wik.Accounts.User.Senders
  alias Wik.Accounts.User.Validations

  postgres do
    table "users"
    repo Wik.Repo
  end

  admin do
    actor? true
    label_field :email
    relationship_display_fields [:email]
  end

  authentication do
    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end
    end

    tokens do
      enabled? true
      token_resource Wik.Accounts.Token
      signing_secret Wik.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      magic_link do
        identity_field :email
        registration_enabled? true
        require_interaction? true

        sender Senders.SendMagicLinkEmail
      end

      remember_me :remember_me
    end
  end

  actions do
    defaults [:read]

    create :create_from_external_identity

    create :create_dev_user do
      accept [:email, :role]
    end

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    read :get_by_email do
      description "Looks up a user by their email"
      get_by :email
    end

    create :sign_in_with_magic_link do
      description "Sign in or register a user with magic link."

      argument :token, :string do
        description "The token from the magic link that was sent to the user"
        allow_nil? false
      end

      argument :remember_me, :boolean do
        description "Whether to generate a remember me token"
        allow_nil? true
      end

      upsert? true
      upsert_identity :unique_email
      upsert_fields [:email]

      # Uses the information from the token to create or sign in the user
      change AshAuthentication.Strategy.MagicLink.SignInChange

      change {AshAuthentication.Strategy.RememberMe.MaybeGenerateTokenChange,
              strategy_name: :remember_me}

      metadata :token, :string do
        allow_nil? false
      end
    end

    action :request_magic_link do
      argument :email, :ci_string do
        allow_nil? false
      end

      run AshAuthentication.Strategy.MagicLink.Request
    end

    update :update_tz do
      accept [:tz]
      require_atomic? false
      validate Validations.Tz
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy action_type(:read) do
      # TODO : implement proper read policies
      authorize_if always()
    end

    policy action(:update_tz) do
      authorize_if expr(id == ^actor(:id))
      authorize_if actor_attribute_equals(:role, :superadmin)
    end
  end

  changes do
    change Changes.MakeFirstUserSuperadmin, on: :create
  end

  attributes do
    uuid_primary_key :id

    attribute :role, :atom do
      constraints one_of: [:user, :superadmin]
      public? true
      allow_nil? false
      default :user
    end

    attribute :email, :ci_string do
      allow_nil? true
      public? true
    end

    attribute :tz, :string do
      allow_nil? true
      public? true
    end
  end

  relationships do
    has_many :external_identities, Wik.Access.ExternalIdentity do
      destination_attribute :user_id
    end

    many_to_many :groups, Group do
      through GroupUserRelation
      source_attribute_on_join_resource :user_id
      destination_attribute_on_join_resource :group_id
    end
  end

  identities do
    identity :unique_email, [:email]
  end
end

defimpl String.Chars, for: Wik.Accounts.User do
  def to_string(%Wik.Accounts.User{email: email}),
    do: email |> Kernel.to_string() |> String.split("@") |> List.first()
end
