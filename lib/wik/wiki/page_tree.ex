defmodule Wik.Wiki.PageTree do
  alias Wik.Accounts.Group
  alias Wik.Wiki.PageTree.Node
  alias Wik.Wiki.PageTree.TreeQueries

  use Ash.Resource,
    otp_app: :wik,
    domain: Wik.Wiki,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshPhoenix]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          nodes: [Node.t()]
        }

  defdelegate get_node(nodes, node_id), to: TreeQueries
  defdelegate get_node_ancestors(nodes, node_id), to: TreeQueries
  defdelegate get_node_by_path(nodes, path), to: TreeQueries
  defdelegate get_node_path(nodes, node_id), to: TreeQueries
  defdelegate get_child_nodes(nodes, node_id), to: TreeQueries
  defdelegate get_child_nodes_with_pages(nodes, node_id), to: TreeQueries
  defdelegate get_nodes_with_child_pages(nodes), to: TreeQueries
  defdelegate get_valid_parent_nodes(nodes, node_id), to: TreeQueries
  defdelegate get_node_tree(nodes, source_node_id, max_depth), to: TreeQueries
  defdelegate get_root_descendant_tree(nodes, max_depth), to: TreeQueries
  defdelegate get_root_nodes(nodes), to: TreeQueries
  defdelegate build_tree(nodes), to: TreeQueries

  def destroy_node(page_tree, node_id, opts \\ []) do
    # Temporary wrapper until ash fixes the following bug: 
    # "scope lost on Ash.update for a record #2662"
    # https://github.com/ash-project/ash/issues/2662
    {destroy_page?, opts} = Keyword.pop(opts, :destroy_page?, false)
    {scope, opts} = Keyword.pop!(opts, :scope)
    opts = scope |> Ash.Scope.to_opts(opts)
    opts = Keyword.put(opts, :action, :destroy_node)

    page_tree
    |> Ash.update(%{node_id: node_id, destroy_page?: destroy_page?}, opts)
  end

  postgres do
    table "page_trees"
    repo Wik.Repo
  end

  code_interface do
    define :create
    define :add_child, args: [:parent_id, :slug, :title]
    define :create_node_at_path, args: [:path, :title, :page_id, :titles]
    define :link_page, args: [:node_id, :page_id]
    define :move_node, args: [:node_id, :new_parent_id]
    define :ensure, action: :ensure, args: []

    # Used for authorization semantics with Ash.can?(), not for mutating data
    define :manage_tree, action: :manage_tree, args: []
  end

  actions do
    defaults [:read]

    create :create do
      change Wik.Wiki.PageTree.Changes.ValidateUniqueSiblingSlugs
    end

    action :ensure, :struct do
      constraints instance_of: __MODULE__
      run Wik.Wiki.PageTree.Actions.Ensure
    end

    update :manage_tree, do: require_atomic?(false)

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

      change Wik.Wiki.PageTree.Changes.AddChild
      change Wik.Wiki.PageTree.Changes.ValidateUniqueSiblingSlugs
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

      argument :titles, {:array, :string} do
        allow_nil? true
      end

      change Wik.Wiki.PageTree.Changes.CreateNodeAtPath
      change Wik.Wiki.PageTree.Changes.ValidateUniqueSiblingSlugs
    end

    update :link_page do
      require_atomic? false

      argument :node_id, :integer do
        allow_nil? false
      end

      argument :page_id, :uuid do
        allow_nil? false
      end

      change Wik.Wiki.PageTree.Changes.LinkPage
    end

    update :destroy_node do
      require_atomic? false

      argument :node_id, :integer do
        allow_nil? false
      end

      argument :destroy_page?, :boolean do
        allow_nil? false
        default false
      end

      change Wik.Wiki.PageTree.Changes.DestroyNode
    end

    update :move_node do
      require_atomic? false

      argument :node_id, :integer do
        allow_nil? false
      end

      argument :new_parent_id, :integer do
        allow_nil? true
      end

      change Wik.Wiki.PageTree.Changes.MoveNode
      change Wik.Wiki.PageTree.Changes.ValidateUniqueSiblingSlugs
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :superadmin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if Group.Checks.ActorIsMemberOfResourceGroup
    end

    policy action_type(:create) do
      authorize_if Group.Checks.ActorIsMemberOfCurrentTenantGroup
    end

    policy action_type(:update) do
      authorize_if Group.Checks.ActorCanManageResourceGroup
    end

    policy action(:ensure) do
      authorize_if Group.Checks.ActorIsMemberOfCurrentTenantGroup
    end

    policy action(:manage_tree) do
      authorize_if Group.Checks.ActorCanManageResourceGroup
    end
  end

  multitenancy do
    strategy :attribute
    attribute :group_id
    parse_attribute {Wik.Accounts, :group_name_to_id, []}
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :nodes, {:array, Wik.Wiki.PageTree.Node} do
      allow_nil? false
      public? true
      default fn -> [] end
    end
  end

  relationships do
    belongs_to :group, Wik.Accounts.Group do
      destination_attribute :id
      allow_nil? false
    end
  end

  identities do
    identity :unique_group_page_tree, [:group_id]
  end
end
