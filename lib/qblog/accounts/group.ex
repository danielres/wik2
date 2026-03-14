defmodule Qblog.Accounts.Group do
  use Ash.Resource,
    otp_app: :qblog,
    domain: Qblog.Accounts,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "groups"
    repo Qblog.Repo
  end

  actions do
    defaults [
      :read,
      :update,
      :destroy
    ]

    create :create do
      accept [:name]
      change relate_actor(:owner, allow_nil?: false)
    end
  end

  def field_type_for(:name), do: "text"
  def field_type_for(_), do: nil

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :name, :string do
      public? true
      allow_nil? false
    end
  end

  relationships do
    belongs_to :owner, Qblog.Accounts.User do
      destination_attribute :id
    end
  end

  identities do
    identity :unique_name, :name
  end
end
