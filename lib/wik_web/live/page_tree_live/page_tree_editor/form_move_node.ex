defmodule WikWeb.PageTreeLive.PageTreeEditor.FormMoveNode do
  use WikWeb, :live_component

  alias Wik.Wiki.PageTree
  alias WikWeb.PageTreeLive.Components
  alias WikWeb.PageTreeLive.Components.PageTree.ActionButtons
  alias WikWeb.PageTreeLive.PageTreeEditor
  alias WikWeb.PageTreeLive.PageTreeEditor.FlowMoveNode
  alias Utils.Log

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)

    {:ok, socket}
  end

  attr :current_scope, :any, required: true
  attr :editor_id, :string, required: true
  attr :flow, :map, required: true
  attr :page_tree, :map, required: true

  @impl true
  def render(assigns) do
    candidates =
      if assigns.flow.node_id != nil do
        PageTree.get_valid_parent_nodes(assigns.page_tree.nodes, assigns.flow.node_id)
      else
        []
      end

    assigns =
      assigns
      |> assign(candidates: candidates)
      |> assign(
        can_move_to_top?: top_level_candidate?(assigns.page_tree.nodes, assigns.flow.node_id)
      )

    ~H"""
    <div id={@id} data-testid="move-node-modal">
      <div class={[
        "space",
        "flex items-center justify-between gap-3",
        "mb-2"
      ]}>
        <div class={[
          "opacity-80",
          "space-has-[button:hover]:opacity-100",
          "transition",
          "text-sm"
        ]}>
          Top level
        </div>

        <ActionButtons.wrapper :if={@can_move_to_top?}>
          <ActionButtons.button
            data-tip="move to top"
            data-testid="move-node-to-top"
            icon="hero-arrow-turn-down-right-mini"
            phx-click="move_node"
            phx-target={@myself}
            phx-value-new_parent_id=""
            phx-value-node_id={@flow.node_id}
          />
        </ActionButtons.wrapper>
      </div>

      <Components.PageTree.render nodes_flat={@page_tree.nodes}>
        <:action_buttons :let={props}>
          <.action_buttons
            candidates={@candidates}
            node={props.node}
            target={@myself}
          />
        </:action_buttons>

        <:label :let={props}>
          <span>{props.node[:title]}</span>
        </:label>
      </Components.PageTree.render>
    </div>
    """
  end

  defp top_level_candidate?(_nodes, nil), do: false

  defp top_level_candidate?(nodes, node_id) do
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

  @impl true
  def handle_event("move_node", %{"new_parent_id" => new_parent_id}, socket) do
    flow = socket.assigns.flow
    page_tree = socket.assigns.page_tree
    scope = socket.assigns.current_scope

    case FlowMoveNode.submit(flow, page_tree, new_parent_id, scope) do
      {:ok, flow, page_tree} ->
        send(self(), {:page_tree_updated, page_tree})

        send_update(
          PageTreeEditor,
          id: socket.assigns.editor_id,
          flow_move_node: flow
        )

        {:noreply,
         socket
         |> assign(flow: flow, page_tree: page_tree)}

      {:error, flow, err} ->
        Log.scoped_error(scope, err, "page_tree move_node failed")
        {:noreply, socket |> assign(flow: flow)}
    end
  end

  attr :candidates, :list, required: true
  attr :node, :map, required: true
  attr :target, :any, required: true

  defp action_buttons(assigns) do
    candidate_ids = assigns.candidates |> Enum.map(fn e -> e.id end)
    candidate? = assigns.node.id in candidate_ids
    assigns = assigns |> assign(candidate?: candidate?)

    ~H"""
    <ActionButtons.wrapper>
      <ActionButtons.button
        :if={@candidate?}
        data-tip={~s(Move under "#{@node.title}")}
        data-testid={"move-node-to-parent-#{@node.id}"}
        icon="hero-arrow-turn-down-right-mini"
        phx-click="move_node"
        phx-target={@target}
        phx-value-new_parent_id={@node.id}
        phx-value-node_id={@node.id}
      />
    </ActionButtons.wrapper>
    """
  end
end
