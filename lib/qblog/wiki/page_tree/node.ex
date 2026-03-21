defmodule Qblog.Wiki.PageTree.Node do
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    attribute :id, :integer do
      allow_nil? false
      public? true
    end

    attribute :page_id, :uuid do
      allow_nil? true
      public? true
    end

    attribute :parent_id, :integer do
      allow_nil? true
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end
  end
end
