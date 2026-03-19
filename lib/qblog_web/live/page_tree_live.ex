defmodule QblogWeb.PageTreeLive do
  use QblogWeb, :live_view

  alias Qblog.Wiki.PageTree
  alias Qblog.Wiki.PageTree.TreeQueries
  alias QblogWeb.PageTreeLive.Components
  alias Utils.Log

  on_mount {QblogWeb.LiveUserAuth, :live_scope_required}

  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    flat_tree = scope |> get_or_create_page_tree()

    {:ok, socket |> assign_page_tree(flat_tree)}
  end

  defp assign_page_tree(socket, flat_tree) do
    socket
    |> assign(flat_tree: flat_tree)
    |> assign(tree: flat_tree.nodes |> TreeQueries.build_tree())
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
            <div class="card-body">
              No nodes yet.
            </div>
          </div>
        <% else %>
          <Components.page_tree_nodes nodes={@tree} flat_nodes={@flat_tree.nodes} />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("add_root", _params, socket) do
    scope = socket.assigns.current_scope

    case PageTree.add_child(socket.assigns.flat_tree, nil, scope: scope) do
      {:ok, flat_tree} ->
        {:noreply, socket |> assign_page_tree(flat_tree)}

      {:error, err} ->
        Log.scoped_error(scope, err, "flat tree add_root failed")
        {:noreply, socket}
    end
  end

  def handle_event("move_node", %{"node_id" => node_id, "new_parent_id" => new_parent_id}, socket) do
    scope = socket.assigns.current_scope

    case PageTree.move_node(socket.assigns.flat_tree, node_id, new_parent_id, scope: scope) do
      {:ok, flat_tree} ->
        {:noreply, socket |> assign_page_tree(flat_tree)}

      {:error, err} ->
        Log.scoped_error(scope, err, "flat tree move_node failed")
        {:noreply, socket}
    end
  end

  def handle_event("add_child", %{"node_id" => node_id}, socket) do
    scope = socket.assigns.current_scope

    case PageTree.add_child(socket.assigns.flat_tree, node_id, scope: scope) do
      {:ok, flat_tree} ->
        {:noreply, socket |> assign_page_tree(flat_tree)}

      {:error, err} ->
        Log.scoped_error(scope, err, "flat tree add_child failed")
        {:noreply, socket}
    end
  end

  def handle_event("remove_node", %{"node_id" => node_id}, socket) do
    scope = socket.assigns.current_scope

    case PageTree.remove_node(socket.assigns.flat_tree, node_id, scope: scope) do
      {:ok, flat_tree} ->
        {:noreply, socket |> assign_page_tree(flat_tree)}

      {:error, err} ->
        Log.scoped_error(scope, err, "flat tree remove_node failed")
        {:noreply, socket}
    end
  end

  def handle_event("move_to_root", %{"node_id" => node_id}, socket) do
    scope = socket.assigns.current_scope

    case PageTree.move_node(socket.assigns.flat_tree, node_id, nil, scope: scope) do
      {:ok, flat_tree} ->
        {:noreply, socket |> assign_page_tree(flat_tree)}

      {:error, err} ->
        Log.scoped_error(scope, err, "flat tree move_to_root failed")
        {:noreply, socket}
    end
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
