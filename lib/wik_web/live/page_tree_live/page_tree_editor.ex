defmodule WikWeb.PageTreeLive.PageTreeEditor do
  use WikWeb, :live_component

  alias Wik.Wiki.PageTree
  alias WikWeb.Components.Modal
  alias WikWeb.PageTreeLive.Components
  alias WikWeb.PageTreeLive.Components.PageTree.ActionButtons
  alias WikWeb.PageTreeLive.PageTreeEditor.FlowAddChild
  alias WikWeb.PageTreeLive.PageTreeEditor.FlowMoveNode
  alias WikWeb.PageTreeLive.PageTreeEditor.FormAddChild
  alias WikWeb.PageTreeLive.PageTreeEditor.FormMoveNode
  alias Utils.Log

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(debug?: false)
      |> assign_new(:flow_add_child, fn -> FlowAddChild.init(assigns.current_scope) end)
      |> assign_new(:flow_move_node, fn -> FlowMoveNode.init() end)

    {:ok, socket}
  end

  attr :current_scope, :any, required: true
  attr :editable?, :boolean, default: false
  attr :page_tree, :map, required: true

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-end gap-4 mb-2">
        <ActionButtons.wrapper>
          <ActionButtons.button
            :if={@editable?}
            data-tip="add at top level"
            data-testid="page-tree-editor-add-root"
            icon="hero-plus-mini"
            phx-click="add_child_start"
            phx-target={@myself}
            phx-value-node_id=""
          />
        </ActionButtons.wrapper>
      </div>

      <Components.PageTree.render nodes_flat={@page_tree.nodes}>
        <:action_buttons :let={props}>
          <.action_buttons
            :if={@editable?}
            add_child_target={@myself}
            depth={props.depth}
            move_node_target={@myself}
            node={props.node}
            nodes_flat={@page_tree.nodes}
            destroy_node_target={@myself}
          />
        </:action_buttons>

        <:label :let={props}>
          <div class="flex gap-1 items-center">
            <span>{props.node[:title]}</span>

            <.link
              navigate={@current_scope |> link_target_for_node(@page_tree.nodes, props.node)}
              class="opacity-50 hover:opacity-100 transition"
            >
              <.icon name="hero-arrow-up-right-micro" class="" />
            </.link>
            <%= if @debug? do %>
              <span class="badge-xs bg-base-200 px-2 font-mono">{props.node[:slug]}</span>
              <span class="badge-xs bg-base-200 px-2">id {props.node.id}</span>
              <span class="badge-xs bg-base-200 pr-1 opacity-80">
                <span :if={!props.node.page_id}>
                  <.icon name="hero-x-circle-solid" class="text-error size-4" /> no page
                </span>
                <span :if={props.node.page_id}>
                  <.icon name="hero-check-circle-solid" class="text-success size-4" /> page
                </span>
              </span>
            <% end %>
          </div>
        </:label>
      </Components.PageTree.render>

      <Modal.render
        cancel="move_node_cancel"
        cancel_testid="move-node-cancel"
        open?={@flow_move_node.open?}
        phx-target={@myself}
        testid="move-node-dialog"
      >
        <:title>
          <span>Move</span>
          <span class="font-bold" data-testid="move-node-current-node">
            "{current_move_node_title(@page_tree.nodes, @flow_move_node.node_id)}"
          </span>
        </:title>

        <.live_component
          module={FormMoveNode}
          id="modal_move_node"
          current_scope={@current_scope}
          editor_id={@id}
          flow={@flow_move_node}
          page_tree={@page_tree}
        />
      </Modal.render>

      <Modal.render
        cancel="add_child_cancel"
        cancel_testid="add-child-cancel"
        open?={@flow_add_child.open?}
        phx-target={@myself}
        testid="add-child-dialog"
      >
        <.live_component
          module={FormAddChild}
          id="modal_add_child"
          current_scope={@current_scope}
          editor_id={@id}
          flow={@flow_add_child}
          page_tree={@page_tree}
        />
      </Modal.render>
    </div>
    """
  end

  attr :add_child_target, :any, required: true
  attr :depth, :integer, required: true
  attr :move_node_target, :any, required: true
  attr :node, :map, required: true
  attr :nodes_flat, :list, required: true
  attr :destroy_node_target, :any, required: true

  defp action_buttons(assigns) do
    candidates = PageTree.get_valid_parent_nodes(assigns.nodes_flat, assigns.node.id)

    has_candidates? =
      candidates != [] or valid_top_level_parent?(assigns.nodes_flat, assigns.node.id)

    assigns = assigns |> assign(has_candidates?: has_candidates?)

    ~H"""
    <ActionButtons.wrapper>
      <ActionButtons.button
        :if={@node.children == []}
        data-tip="delete"
        data-testid={"page-tree-editor-node-#{@node.id}-remove"}
        icon="hero-x-mark-mini"
        phx-click="destroy_node"
        phx-target={@destroy_node_target}
        phx-value-node_id={@node.id}
        variant="error"
      />

      <ActionButtons.button
        data-tip="add child"
        data-testid={"page-tree-editor-node-#{@node.id}-add-child"}
        icon="hero-plus-mini"
        phx-click="add_child_start"
        phx-target={@add_child_target}
        phx-value-node_id={@node.id}
      />

      <ActionButtons.button
        :if={@has_candidates?}
        data-tip="move"
        data-testid={"page-tree-editor-node-#{@node.id}-move"}
        icon="hero-arrow-turn-down-right-mini"
        phx-click="move_node_start"
        phx-target={@move_node_target}
        phx-value-node_id={@node.id}
      />
    </ActionButtons.wrapper>
    """
  end

  # helpers ==================================================================

  defp link_target_for_node(scope, nodes, node) do
    path = PageTree.get_node_path(nodes, node.id)
    "/#{scope.tenant.slug}/wiki/#{path}"
  end

  defp current_move_node_title(_nodes, nil), do: "Top"

  defp current_move_node_title(nodes, node_id) do
    case PageTree.get_node(nodes, node_id) do
      nil -> "Unknown"
      node -> node.title
    end
  end

  defp valid_top_level_parent?(nodes, node_id) do
    node = PageTree.get_node(nodes, node_id)

    if node == nil do
      false
    else
      root_slugs =
        nodes
        |> PageTree.get_root_nodes()
        |> Enum.reject(&(&1.id == node.id))
        |> Enum.map(& &1.slug)

      node.parent_id != nil and node.slug not in root_slugs
    end
  end

  # move node ================================================================

  @impl true
  def handle_event("move_node_cancel", _params, socket) do
    {:noreply,
     socket
     |> assign(flow_move_node: FlowMoveNode.init())}
  end

  @impl true
  def handle_event("move_node_start", %{"node_id" => node_id}, socket) do
    socket =
      if socket.assigns.editable? do
        socket
        |> assign(flow_move_node: node_id |> FlowMoveNode.open())
      else
        socket
      end

    {:noreply, socket}
  end

  # add child ================================================================

  @impl true
  def handle_event("add_child_cancel", _params, socket) do
    {:noreply,
     socket
     |> assign(flow_add_child: FlowAddChild.init(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("add_child_start", %{"node_id" => node_id}, socket) do
    socket =
      if socket.assigns.editable? do
        socket
        |> assign(flow_add_child: socket.assigns.flow_add_child |> FlowAddChild.open(node_id))
      else
        socket
      end

    {:noreply, socket}
  end

  # remove node ================================================================

  @impl true
  def handle_event("destroy_node", %{"node_id" => node_id}, socket) do
    if socket.assigns.editable? do
      page_tree = socket.assigns.page_tree
      scope = socket.assigns.current_scope

      case PageTree.destroy_node(page_tree, node_id, destroy_page?: true, scope: scope) do
        {:ok, page_tree} ->
          send(self(), {:page_tree_updated, page_tree})

          {:noreply,
           socket
           |> assign(page_tree: page_tree)}

        {:error, err} ->
          Log.scoped_error(scope, err, "page_tree destroy_node failed")
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end
end
