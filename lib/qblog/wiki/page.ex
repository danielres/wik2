defmodule Qblog.Wiki.Page do
  use Ash.Resource,
    otp_app: :qblog,
    domain: Qblog.Wiki,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshPhoenix]

  postgres do
    table "pages"
    repo Qblog.Repo
  end

  actions do
    defaults [
      :read,
      :update,
      :destroy
    ]

    create :create do
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
  end

  multitenancy do
    strategy :attribute
    attribute :group_id
    parse_attribute {Qblog.Accounts, :group_name_to_id, []}
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()
  end

  relationships do
    belongs_to :group, Qblog.Accounts.Group do
      destination_attribute :id
      allow_nil? false
    end

    belongs_to :author, Qblog.Accounts.User do
      destination_attribute :id
      allow_nil? false
    end
  end
end
