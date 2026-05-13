defmodule Wik.Blog.Post do
  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Blog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshPhoenix],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "posts"
    repo Wik.Repo
  end

  actions do
    defaults [
      :read,
      :update,
      :destroy
    ]

    create :create do
      accept [:title, :body]
      change relate_actor(:author, allow_nil?: false)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type(:create) do
      authorize_if always()
    end

    policy action_type(:destroy) do
      authorize_if relates_to_actor_via(:author)
      authorize_if actor_attribute_equals(:role, :superadmin)
    end
  end

  def field_type_for(:body), do: "textarea"
  def field_type_for(_), do: nil

  pub_sub do
    module WikWeb.Endpoint
    prefix "post"
    publish :create, ["created", :_tenant]
  end

  multitenancy do
    strategy :attribute
    attribute :group_id
    parse_attribute {Wik.Accounts, :group_slug_to_id, []}
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :title, :string do
      public? true
      allow_nil? false
    end

    attribute :body, :string do
      public? true
      allow_nil? false
    end
  end

  relationships do
    belongs_to :group, Wik.Accounts.Group do
      destination_attribute :id
      allow_nil? false
    end

    belongs_to :author, Wik.Accounts.User do
      destination_attribute :id
      allow_nil? false
    end
  end
end
