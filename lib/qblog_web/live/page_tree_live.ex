defmodule QblogWeb.PageTreeLive do
  use QblogWeb, :live_view

  alias Qblog.Wiki.PageTree
  alias Qblog.Wiki.PageTree.TreeQueries
  alias QblogWeb.PageTreeLive.Components
  alias Utils.Log

  on_mount {QblogWeb.LiveUserAuth, :live_scope_required}

  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    case Qblog.Wiki.get_page_tree(scope: scope) do
      {:ok, flat_tree} ->
        {:ok, socket |> assign_tree_data(flat_tree)}

      {:error, err} ->
        Log.scoped_error(scope, err, "flat tree get_or_create failed")
        {:ok, socket |> assign_tree_data(%PageTree{nodes: []})}
    end
  end

  defp assign_tree_data(socket, flat_tree) do
    socket |> assign(flat_tree: flat_tree)
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

        <%= if @flat_tree.nodes == [] do %>
          <div class="card bg-base-100 shadow">
            <div class="card-body">
              No nodes yet.
            </div>
          </div>
        <% else %>
          <Components.page_tree_nodes nodes_flat={@flat_tree.nodes} />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("add_root", _params, socket) do
    scope = socket.assigns.current_scope

    case PageTree.add_child(socket.assigns.flat_tree, nil, scope: scope) do
      {:ok, flat_tree} ->
        {:noreply, socket |> assign_tree_data(flat_tree)}

      {:error, err} ->
        Log.scoped_error(scope, err, "flat tree add_root failed")
        {:noreply, socket}
    end
  end

  def handle_event("move_node", %{"node_id" => node_id, "new_parent_id" => new_parent_id}, socket) do
    scope = socket.assigns.current_scope

    case PageTree.move_node(socket.assigns.flat_tree, node_id, new_parent_id, scope: scope) do
      {:ok, flat_tree} ->
        {:noreply, socket |> assign_tree_data(flat_tree)}

      {:error, err} ->
        Log.scoped_error(scope, err, "flat tree move_node failed")
        {:noreply, socket}
    end
  end

  def handle_event("add_child", %{"node_id" => node_id}, socket) do
    scope = socket.assigns.current_scope

    case PageTree.add_child(socket.assigns.flat_tree, node_id, scope: scope) do
      {:ok, flat_tree} ->
        {:noreply, socket |> assign_tree_data(flat_tree)}

      {:error, err} ->
        Log.scoped_error(scope, err, "flat tree add_child failed")
        {:noreply, socket}
    end
  end

  def handle_event("remove_node", %{"node_id" => node_id}, socket) do
    scope = socket.assigns.current_scope

    case PageTree.remove_node(socket.assigns.flat_tree, node_id, scope: scope) do
      {:ok, flat_tree} ->
        {:noreply, socket |> assign_tree_data(flat_tree)}

      {:error, err} ->
        Log.scoped_error(scope, err, "flat tree remove_node failed")
        {:noreply, socket}
    end
  end

  def handle_event("move_to_root", %{"node_id" => node_id}, socket) do
    scope = socket.assigns.current_scope

    case PageTree.move_node(socket.assigns.flat_tree, node_id, nil, scope: scope) do
      {:ok, flat_tree} ->
        {:noreply, socket |> assign_tree_data(flat_tree)}

      {:error, err} ->
        Log.scoped_error(scope, err, "flat tree move_to_root failed")
        {:noreply, socket}
    end
  end
end
