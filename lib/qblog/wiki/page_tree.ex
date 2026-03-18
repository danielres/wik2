defmodule Qblog.Wiki.PageTree do
  use Ash.Resource,
    otp_app: :qblog,
    domain: Qblog.Wiki,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshPhoenix]

  sqlite do
    table "page_trees"
    repo Qblog.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:tree]
    end
  end

  policies do
    # TODO: tighten policies
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type(:create) do
      authorize_if always()
    end

    policy action_type(:update) do
      authorize_if always()
    end

    policy action_type(:destroy) do
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

    attribute :tree, :map do
      allow_nil? false
      public? true
      default fn -> %{"roots" => []} end
    end
  end

  relationships do
    belongs_to :group, Qblog.Accounts.Group do
      destination_attribute :id
      allow_nil? false
    end
  end

  identities do
    identity :unique_group_page_tree, [:group_id]
  end
end
