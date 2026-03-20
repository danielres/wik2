defmodule QblogWeb.PageTreeLive do
  use QblogWeb, :live_view

  alias Qblog.Wiki.PageTree
  alias QblogWeb.PageTreeLive.Components
  alias QblogWeb.PageTreeLive.Helpers
  alias Utils.Log

  on_mount {QblogWeb.LiveUserAuth, :live_scope_required}

  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    case Qblog.Wiki.get_page_tree(scope: scope) do
      {:ok, page_tree} ->
        {:ok,
         socket
         |> assign(page_tree: page_tree)
         |> assign(moved_node_id: nil)}

      {:error, err} ->
        Log.scoped_error(scope, err, "page_tree get_or_create failed")
        {:ok, socket |> assign(page_tree: %PageTree{nodes: []})}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} scope={@current_scope}>
      <div class="space-y-4">
        <div class="flex items-center justify-between gap-4">
          <h1 class="text-2xl font-[100]">Page Tree</h1>
          <.button
            phx-click="add_child"
            phx-value-node_id=""
            class="btn btn-circle bg-base-100"
          >
            <.icon name="hero-plus-mini" />
            <span class="sr-only">Add root node</span>
          </.button>
        </div>

        <Components.MoveNode.Dialog.dialog
          moved_node_id={@moved_node_id}
          nodes_flat={@page_tree.nodes}
        />

        <%= if @page_tree.nodes == [] do %>
          <div class="card bg-base-100 shadow">
            <div class="card-body">
              No nodes yet.
            </div>
          </div>
        <% else %>
          <Components.PagesTree.render nodes_flat={@page_tree.nodes}>
            <:action_buttons :let={props}>
              <.action_buttons
                depth={props.depth}
                node={props.node}
                nodes_flat={@page_tree.nodes}
              />
            </:action_buttons>
          </Components.PagesTree.render>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("dialog_keydown_escape", _params, socket) do
    {:noreply, socket |> assign(moved_node_id: nil)}
  end

  def handle_event("move_node_start", params, socket) do
    {:noreply, socket |> assign(moved_node_id: params["node_id"] |> String.to_integer())}
  end

  def handle_event("move_node_cancel", _params, socket) do
    {:noreply, socket |> assign(moved_node_id: nil)}
  end

  def handle_event("move_node", %{"new_parent_id" => new_parent_id}, socket) do
    scope = socket.assigns.current_scope

    case PageTree.move_node(
           socket.assigns.page_tree,
           socket.assigns.moved_node_id,
           new_parent_id,
           scope: scope
         ) do
      {:ok, page_tree} ->
        {
          :noreply,
          socket
          |> assign(page_tree: page_tree)
          |> assign(moved_node_id: nil)
        }

      {:error, err} ->
        Log.scoped_error(scope, err, "page_tree move_node failed")
        {:noreply, socket}
    end
  end

  def handle_event("add_child", %{"node_id" => node_id}, socket) do
    scope = socket.assigns.current_scope

    case PageTree.add_child(socket.assigns.page_tree, node_id, scope: scope) do
      {:ok, page_tree} ->
        {:noreply, socket |> assign(page_tree: page_tree)}

      {:error, err} ->
        Log.scoped_error(scope, err, "page_tree add_child failed")
        {:noreply, socket}
    end
  end

  def handle_event("remove_node", %{"node_id" => node_id}, socket) do
    scope = socket.assigns.current_scope

    case PageTree.remove_node(socket.assigns.page_tree, node_id, scope: scope) do
      {:ok, page_tree} ->
        {:noreply, socket |> assign(page_tree: page_tree)}

      {:error, err} ->
        Log.scoped_error(scope, err, "page_tree remove_node failed")
        {:noreply, socket}
    end
  end

  attr :node, :map, required: true
  attr :nodes_flat, :list, required: true
  attr :depth, :integer, required: true

  defp action_buttons(assigns) do
    candidates = Helpers.parent_options(assigns.nodes_flat, assigns.node.id)
    assigns = assigns |> assign(has_candidates?: candidates |> Enum.count() > 0)

    ~H"""
    <Components.PagesTree.ActionButtonsWrapper.render>
      <Components.PagesTree.ActionButton.render
        :if={@node.children == []}
        phx-value-node_id={@node.id}
        phx-click="remove_node"
        icon="hero-x-mark-mini"
        data-tip="delete"
        variant="error"
      />

      <Components.PagesTree.ActionButton.render
        :if={@has_candidates?}
        phx-value-node_id={@node.id}
        phx-click="move_node_start"
        icon="hero-arrow-turn-down-right-mini"
        data-tip="move"
      />

      <Components.PagesTree.ActionButton.render
        phx-value-node_id={@node.id}
        phx-click="add_child"
        icon="hero-plus-mini"
        data-tip="add child"
      />
    </Components.PagesTree.ActionButtonsWrapper.render>
    """
  end
end
