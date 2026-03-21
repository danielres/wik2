defmodule QblogWeb.PageTreeLive.PageTreeEditor do
  use QblogWeb, :live_component

  alias Qblog.Wiki
  alias QblogWeb.PageTreeLive.Components
  alias QblogWeb.PageTreeLive.Components.MoveNode.Dialog
  alias QblogWeb.PageTreeLive.Components.PageTree.ActionButtons
  alias QblogWeb.PageTreeLive.Helpers
  alias Qblog.Wiki.PageTree
  alias Utils.Log

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:moved_node_id, fn -> nil end)

    socket =
      case socket.assigns do
        %{page_tree: %PageTree{}} ->
          socket

        %{current_scope: scope} ->
          case Wiki.get_page_tree(scope: scope) do
            {:ok, page_tree} ->
              assign(socket, :page_tree, page_tree)

            {:error, err} ->
              Log.scoped_error(scope, err, "page_tree get_or_create failed")
              assign(socket, :page_tree, %PageTree{nodes: []})
          end
      end

    {:ok, socket}
  end

  attr :current_scope, :any, required: true
  attr :editable?, :boolean, default: false

  def render(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between gap-4">
        <h1 class="text-2xl font-[100]">Page Tree</h1>
        <.button
          :if={@editable?}
          phx-click="add_child"
          phx-target={@myself}
          phx-value-node_id=""
          class="btn btn-circle bg-base-100"
        >
          <.icon name="hero-plus-mini" />
          <span class="sr-only">Add root node</span>
        </.button>
      </div>

      <Dialog.dialog
        moved_node_id={@moved_node_id}
        nodes_flat={@page_tree.nodes}
        target={@myself}
      />

      <%= if @page_tree.nodes == [] do %>
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            No nodes yet.
          </div>
        </div>
      <% else %>
        <Components.PageTree.render nodes_flat={@page_tree.nodes}>
          <:action_buttons :let={props}>
            <.action_buttons
              :if={@editable?}
              phx-target={@myself}
              depth={props.depth}
              node={props.node}
              nodes_flat={@page_tree.nodes}
            />
          </:action_buttons>
        </Components.PageTree.render>
      <% end %>
    </div>
    """
  end

  attr :node, :map, required: true
  attr :nodes_flat, :list, required: true
  attr :depth, :integer, required: true
  attr :"phx-target", :any, required: false

  defp action_buttons(assigns) do
    candidates = Helpers.parent_options(assigns.nodes_flat, assigns.node.id)
    assigns = assigns |> assign(has_candidates?: candidates |> Enum.count() > 0)

    ~H"""
    <ActionButtons.wrapper>
      <ActionButtons.button
        :if={@node.children == []}
        phx-value-node_id={@node.id}
        phx-click="remove_node"
        phx-target={assigns[:"phx-target"]}
        icon="hero-x-mark-mini"
        data-tip="delete"
        variant="error"
      />

      <ActionButtons.button
        phx-value-node_id={@node.id}
        phx-click="add_child"
        phx-target={assigns[:"phx-target"]}
        icon="hero-plus-mini"
        data-tip="add child"
      />

      <ActionButtons.button
        :if={@has_candidates?}
        phx-value-node_id={@node.id}
        phx-click="move_node_start"
        phx-target={assigns[:"phx-target"]}
        icon="hero-arrow-turn-down-right-mini"
        data-tip="move"
      />
    </ActionButtons.wrapper>
    """
  end

  def handle_event("move_node_start", params, socket) do
    {:noreply, socket |> assign(moved_node_id: params["node_id"] |> String.to_integer())}
  end

  def handle_event("dialog_keydown_escape", _params, socket) do
    {:noreply, assign(socket, :moved_node_id, nil)}
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
    parent_node_id = if node_id == "", do: nil, else: node_id

    case PageTree.add_child(socket.assigns.page_tree, parent_node_id, scope: scope) do
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
end
