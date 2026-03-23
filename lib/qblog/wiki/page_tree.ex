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
    define :add_child, args: [:parent_id, :slug]
    define :remove_node, args: [:node_id]
    define :move_node, args: [:node_id, :new_parent_id]
  end

  actions do
    defaults [
      :read,
      :destroy,
      :create
    ]

    action :get_or_create_page_tree, :struct do
      constraints instance_of: __MODULE__
      run Qblog.Wiki.PageTree.Actions.GetOrCreate
    end

    update :add_child do
      argument :parent_id, :integer do
        allow_nil? true
      end

      argument :slug, :string do
        allow_nil? false
      end

      change Qblog.Wiki.PageTree.Changes.AddChild
    end

    update :remove_node do
      argument :node_id, :integer do
        allow_nil? false
      end

      change Qblog.Wiki.PageTree.Changes.RemoveNode
    end

    update :move_node do
      argument :node_id, :integer do
        allow_nil? false
      end

      argument :new_parent_id, :integer do
        allow_nil? true
      end

      change Qblog.Wiki.PageTree.Changes.MoveNode
    end
  end

  policies do
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

    policy action(:get_or_create_page_tree) do
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
