defmodule QblogWeb.PageTreeLive.PageTreeEditor do
  use QblogWeb, :live_component

  alias Qblog.Wiki.PageTree
  alias QblogWeb.Components.Modal
  alias QblogWeb.PageTreeLive.Components
  alias QblogWeb.PageTreeLive.Components.PageTree.ActionButtons
  alias QblogWeb.PageTreeLive.Helpers
  alias QblogWeb.PageTreeLive.PageTreeEditor.AddChildFlow
  alias QblogWeb.PageTreeLive.PageTreeEditor.FormAddChild
  alias QblogWeb.PageTreeLive.PageTreeEditor.FormMoveNode
  alias QblogWeb.PageTreeLive.PageTreeEditor.MoveNodeFlow
  alias Utils.Log

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:add_child_flow, fn -> AddChildFlow.init(assigns.current_scope) end)
      |> assign_new(:move_node_flow, fn -> MoveNodeFlow.init() end)

    {:ok, socket}
  end

  attr :current_scope, :any, required: true
  attr :editable?, :boolean, default: false
  attr :page_tree, :map, required: true

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between gap-4">
        <h1 class="text-2xl font-[100]">Page Tree</h1>
        <ActionButtons.wrapper>
          <ActionButtons.button
            :if={@editable?}
            class="[&:not(:hover)]:bg-base-100"
            data-tip="add at top level"
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
            remove_target={@myself}
          />
        </:action_buttons>
      </Components.PageTree.render>

      <Modal.render
        cancel="move_node_cancel"
        open?={@move_node_flow.open?}
        phx-target={@myself}
      >
        <.live_component
          module={FormMoveNode}
          id="modal_move_node"
          current_scope={@current_scope}
          editor_id={@id}
          flow={@move_node_flow}
          page_tree={@page_tree}
        />
      </Modal.render>

      <Modal.render
        cancel="add_child_cancel"
        open?={@add_child_flow.open?}
        phx-target={@myself}
      >
        <:title>
          <span>Add child under</span>
          <span class="font-bold">
            {Helpers.get_node_by_id(@page_tree.nodes, @add_child_flow.parent_id).slug}
          </span>
        </:title>
        <.live_component
          module={FormAddChild}
          id="modal_add_child"
          current_scope={@current_scope}
          editor_id={@id}
          flow={@add_child_flow}
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
  attr :remove_target, :any, required: true

  defp action_buttons(assigns) do
    candidates = assigns.nodes_flat |> Helpers.parent_options(assigns.node.id)
    assigns = assigns |> assign(has_candidates?: candidates |> Enum.count() > 0)

    ~H"""
    <ActionButtons.wrapper>
      <ActionButtons.button
        :if={@node.children == []}
        data-tip="delete"
        icon="hero-x-mark-mini"
        phx-click="remove_node"
        phx-target={@remove_target}
        phx-value-node_id={@node.id}
        variant="error"
      />

      <ActionButtons.button
        data-tip="add child"
        icon="hero-plus-mini"
        phx-click="add_child_start"
        phx-target={@add_child_target}
        phx-value-node_id={@node.id}
      />

      <ActionButtons.button
        :if={@has_candidates?}
        data-tip="move"
        icon="hero-arrow-turn-down-right-mini"
        phx-click="move_node_start"
        phx-target={@move_node_target}
        phx-value-node_id={@node.id}
      />
    </ActionButtons.wrapper>
    """
  end

  # move node ================================================================

  @impl true
  def handle_event("move_node_cancel", _params, socket) do
    {:noreply,
     socket
     |> assign(move_node_flow: MoveNodeFlow.init())}
  end

  @impl true
  def handle_event("move_node_start", %{"node_id" => node_id}, socket) do
    {:noreply,
     socket
     |> assign(move_node_flow: node_id |> MoveNodeFlow.open())}
  end

  # add child ================================================================

  @impl true
  def handle_event("add_child_cancel", _params, socket) do
    {:noreply,
     socket
     |> assign(add_child_flow: AddChildFlow.init(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("add_child_start", %{"node_id" => node_id}, socket) do
    {:noreply,
     socket
     |> assign(add_child_flow: socket.assigns.add_child_flow |> AddChildFlow.open(node_id))}
  end

  # remove node ================================================================

  @impl true
  def handle_event("remove_node", %{"node_id" => node_id}, socket) do
    page_tree = socket.assigns.page_tree
    scope = socket.assigns.current_scope

    case PageTree.remove_node(page_tree, node_id, scope: scope) do
      {:ok, page_tree} ->
        send(self(), {:page_tree_updated, page_tree})

        {:noreply,
         socket
         |> assign(page_tree: page_tree)}

      {:error, err} ->
        Log.scoped_error(scope, err, "page_tree remove_node failed")
        {:noreply, socket}
    end
  end
end
