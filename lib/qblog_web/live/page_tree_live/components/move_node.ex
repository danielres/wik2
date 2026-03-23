defmodule QblogWeb.PageTreeLive.Components.MoveNode do
  use Phoenix.Component

  alias Qblog.Wiki.PageTree.TreeQueries
  alias QblogWeb.PageTreeLive.Components
  alias QblogWeb.PageTreeLive.Components.PageTree.ActionButtons
  alias QblogWeb.PageTreeLive.Helpers

  attr :moved_node_id, :integer, default: nil
  attr :nodes_flat, :list, required: true
  attr :target, :any, required: true

  def dialog(assigns) do
    node = assigns.nodes_flat |> Helpers.get_node_by_id(assigns.moved_node_id)

    assigns =
      assigns
      |> assign(node: node)
      |> assign(nodes_tree: assigns.nodes_flat |> TreeQueries.build_tree())

    ~H"""
    <div class={[
      "group",
      "flex items-center justify-between gap-3",
      "mb-2"
    ]}>
      <div class={[
        "opacity-80",
        "group-has-[button:hover]:opacity-100",
        "transition",
        "text-sm"
      ]}>
        Top level
      </div>

      <ActionButtons.wrapper>
        <ActionButtons.button
          data-tip="move to top"
          icon="hero-arrow-turn-down-right-mini"
          phx-click="move_node"
          phx-target={@target}
          phx-value-new_parent_id=""
          phx-value-node_id={@moved_node_id}
        />
      </ActionButtons.wrapper>
    </div>

    <Components.PageTree.render nodes_flat={@nodes_flat}>
      <:action_buttons :let={props}>
        <.action_buttons
          candidates={Helpers.parent_options(@nodes_flat, @moved_node_id)}
          node={props.node}
          nodes_flat={@nodes_flat}
          target={@target}
        />
      </:action_buttons>
    </Components.PageTree.render>
    """
  end

  attr :candidates, :list, required: true
  attr :node, :map, required: true
  attr :nodes_flat, :list, required: true
  attr :target, :any, required: true

  defp action_buttons(assigns) do
    candidate_ids = assigns.candidates |> Enum.map(fn e -> e.id end)
    candidate? = assigns.node.id in candidate_ids
    assigns = assigns |> assign(candidate?: candidate?)

    ~H"""
    <ActionButtons.wrapper>
      <ActionButtons.button
        :if={@candidate?}
        data-tip={ "move under #{@node.slug}" }
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
