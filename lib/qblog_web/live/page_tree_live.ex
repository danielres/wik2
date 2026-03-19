defmodule QblogWeb.PageTreeLive do
  use QblogWeb, :live_view

  alias Qblog.Wiki.PageTree
  alias Qblog.Wiki.PageTree.TreeQueries
  alias Utils.Log

  on_mount {QblogWeb.LiveUserAuth, :live_scope_required}

  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    page_tree = scope |> get_or_create_page_tree()
    tree = page_tree.nodes |> TreeQueries.build_tree()

    {:ok,
     socket
     |> assign(page_tree: page_tree)
     |> assign(tree: tree)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} scope={@current_scope}>
      <div class="space-y-4">
        <div class="flex items-center justify-between gap-4">
          <h1 class="text-2xl font-[100]">Page Tree</h1>

          <.button phx-click="add_root" class="btn btn-circle bg-base-100">
            <.icon name="hero-plus-mini" />
            <span class="sr-only">Add root node</span>
          </.button>
        </div>

        <%= if @tree == [] do %>
          <div class="card bg-base-100 shadow">
            <div class="card-body text-base-content/70">
              No nodes yet.
            </div>
          </div>
        <% else %>
          <div class="space-y-0">
            <.page_tree_nodes nodes={@tree} />
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("add_root", _params, socket) do
    scope = socket.assigns.current_scope

    case PageTree.add_child(socket.assigns.page_tree, nil, scope: scope) do
      {:ok, page_tree} ->
        {:noreply, socket |> assign_page_tree(page_tree)}

      {:error, err} ->
        Log.scoped_error(scope, err, "page tree add_root failed")
        {:noreply, socket}
    end
  end

  def handle_event("add_child", %{"node_id" => node_id}, socket) do
    scope = socket.assigns.current_scope
    node_id = String.to_integer(node_id)

    case PageTree.add_child(socket.assigns.page_tree, node_id, scope: scope) do
      {:ok, page_tree} ->
        {:noreply, socket |> assign_page_tree(page_tree)}

      {:error, err} ->
        Log.scoped_error(scope, err, "page tree add_child failed")
        {:noreply, socket}
    end
  end

  def handle_event("remove_node", %{"node_id" => node_id}, socket) do
    scope = socket.assigns.current_scope
    node_id = String.to_integer(node_id)

    case PageTree.remove_node(socket.assigns.page_tree, node_id, scope: scope) do
      {:ok, page_tree} ->
        {:noreply, socket |> assign_page_tree(page_tree)}

      {:error, err} ->
        Log.scoped_error(scope, err, "page tree remove_node failed")
        {:noreply, socket}
    end
  end

  def handle_event("move_to_root", %{"node_id" => node_id}, socket) do
    scope = socket.assigns.current_scope
    node_id = String.to_integer(node_id)

    case PageTree.move_node(socket.assigns.page_tree, node_id, nil, scope: scope) do
      {:ok, page_tree} ->
        {:noreply, socket |> assign_page_tree(page_tree)}

      {:error, err} ->
        Log.scoped_error(scope, err, "page tree move_to_root failed")
        {:noreply, socket}
    end
  end

  defp has_children?(node), do: node.children != []

  attr :nodes, :list, required: true
  attr :root?, :boolean, default: false
  attr :depth, :integer, default: 0

  defp page_tree_nodes(assigns) do
    ~H"""
    <ul class="space-y-3">
      <%= for node <- @nodes do %>
        <li>
          <.page_tree_node node={node} root?={@root?} depth={@depth} />
        </li>
      <% end %>
    </ul>
    """
  end

  attr :node, :map, required: true
  attr :root?, :boolean, default: false
  attr :depth, :integer

  defp page_tree_node(assigns) do
    ~H"""
    <div class={["card bg-base-100", @depth > 0 and "border-b-4 border-black/10 rounded-none"]}>
      <div class={["card-body", @depth > 0 and "pr-0"]}>
        <div class="flex items-center justify-between gap-3">
          <div>
            <div>Node {@node.id}</div>
            <div class="text-sm opacity-70">
              <%= if @node.page_id do %>
                page: {@node.page_id}
              <% else %>
                no page
              <% end %>
            </div>
          </div>

          <div class="flex flex-wrap gap-2">
            <.action_buttons root?={@root?} node={@node} />
          </div>
        </div>

        <%= if has_children?(@node) do %>
          <div class="ml-4 border-l-4 border-black/10 pl-0">
            <.page_tree_nodes nodes={@node.children} root?={false} depth={@depth + 1} />
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  attr :node, :map, required: true
  attr :root?, :boolean, default: false

  defp action_buttons(assigns) do
    ~H"""
    <.button
      phx-click="add_child"
      phx-value-node_id={@node.id}
      class="btn btn-sm btn-circle"
    >
      <.icon name="hero-plus-mini" />
      <span class="sr-only">Add child</span>
    </.button>

    <.button
      :if={!@root?}
      phx-click="move_to_root"
      phx-value-node_id={@node.id}
      class="btn btn-sm btn-circle"
    >
      <.icon name="hero-chevron-double-up-mini" />
      <span class="sr-only">Move to root</span>
    </.button>

    <.button
      phx-click="remove_node"
      phx-value-node_id={@node.id}
      disabled={@node.children != []}
      class={[
        "btn btn-sm btn-error btn-circle"
      ]}
    >
      <.icon name="hero-x-mark-mini" />
      <span class="sr-only">Delete</span>
    </.button>
    """
  end

  defp assign_page_tree(socket, page_tree) do
    socket
    |> assign(page_tree: page_tree)
    |> assign(tree: page_tree.nodes |> TreeQueries.build_tree())
  end

  defp get_or_create_page_tree(nil), do: %PageTree{nodes: []}

  defp get_or_create_page_tree(scope) do
    case Qblog.Wiki.PageTree
         |> Ash.Query.for_read(:read)
         |> Ash.read_one(scope: scope) do
      {:ok, %PageTree{} = page_tree} ->
        page_tree

      {:ok, nil} ->
        case PageTree.create(%{}, scope: scope) do
          {:ok, page_tree} ->
            page_tree

          {:error, err} ->
            Log.scoped_error(scope, err, "page tree create failed")
            %PageTree{nodes: []}
        end

      {:error, err} ->
        Log.scoped_error(scope, err, "page tree read failed")
        %PageTree{nodes: []}
    end
  end
end
