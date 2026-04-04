defmodule Qblog.Wiki.PageTree do
  use Ash.Resource,
    otp_app: :qblog,
    domain: Qblog.Wiki,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshPhoenix]

  postgres do
    table "page_trees"
    repo Qblog.Repo
  end

  code_interface do
    define :create
    define :add_child, args: [:parent_id, :slug, :title]
    define :create_node_at_path, args: [:path, :title, :page_id]
    define :link_page, args: [:node_id, :page_id]
    define :remove_node, args: [:node_id]
    define :move_node, args: [:node_id, :new_parent_id]
    define :ensure, action: :ensure, args: []
  end

  actions do
    defaults [
      :read,
      :destroy
    ]

    create :create do
      change Qblog.Wiki.PageTree.Changes.ValidateUniqueSiblingSlugs
    end

    action :ensure, :struct do
      constraints instance_of: __MODULE__
      run Qblog.Wiki.PageTree.Actions.Ensure
    end

    update :add_child do
      require_atomic? false

      argument :parent_id, :integer do
        allow_nil? true
      end

      argument :slug, :string do
        allow_nil? false
      end

      argument :title, :string do
        allow_nil? false
      end

      change Qblog.Wiki.PageTree.Changes.AddChild
      change Qblog.Wiki.PageTree.Changes.ValidateUniqueSiblingSlugs
    end

    update :create_node_at_path do
      require_atomic? false

      argument :path, :string do
        allow_nil? false
      end

      argument :title, :string do
        allow_nil? false
      end

      argument :page_id, :uuid do
        allow_nil? false
      end

      change Qblog.Wiki.PageTree.Changes.CreateByPath
      change Qblog.Wiki.PageTree.Changes.ValidateUniqueSiblingSlugs
    end

    update :link_page do
      require_atomic? false

      argument :node_id, :integer do
        allow_nil? false
      end

      argument :page_id, :uuid do
        allow_nil? false
      end

      change Qblog.Wiki.PageTree.Changes.LinkPage
    end

    update :remove_node do
      require_atomic? false

      argument :node_id, :integer do
        allow_nil? false
      end

      change Qblog.Wiki.PageTree.Changes.RemoveNode
    end

    update :move_node do
      require_atomic? false

      argument :node_id, :integer do
        allow_nil? false
      end

      argument :new_parent_id, :integer do
        allow_nil? true
      end

      change Qblog.Wiki.PageTree.Changes.MoveNode
      change Qblog.Wiki.PageTree.Changes.ValidateUniqueSiblingSlugs
    end
  end

  policies do
    policy action_type(:read) do
      # TODO: implement proper permissions
      authorize_if always()
    end

    policy action_type(:create) do
      # TODO: implement proper permissions
      authorize_if always()
    end

    policy action_type(:update) do
      # TODO: implement proper permissions
      authorize_if always()
    end

    policy action_type(:destroy) do
      # TODO: implement proper permissions
      authorize_if always()
    end

    policy action(:ensure) do
      # TODO: implement proper permissions
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

    attribute :nodes, {:array, Qblog.Wiki.PageTree.Node} do
      allow_nil? false
      public? true
      default fn -> [] end
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
