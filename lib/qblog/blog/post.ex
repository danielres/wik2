defmodule Qblog.Blog.Post do
  use Ash.Resource,
    otp_app: :qblog,
    domain: Qblog.Blog,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshPhoenix]

  sqlite do
    table "posts"
    repo Qblog.Repo
  end

  actions do
    defaults [
      :read,
      :update,
      :destroy,
      create: [:title, :body]
    ]
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type(:create) do
      authorize_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :title, :string do
      public? true
      allow_nil? false
    end

    attribute :body, :string do
      public? true
      allow_nil? false
    end
  end
end
