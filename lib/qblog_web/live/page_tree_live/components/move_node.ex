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
    assigns =
      assigns
      |> assign(
        node: assigns.nodes_flat |> Enum.find(fn node -> node.id == assigns.moved_node_id end)
      )
      |> assign(:nodes_tree, assigns.nodes_flat |> TreeQueries.build_tree())

    ~H"""
    <h3 class="mb-2">Move <span class="font-bold">node {@node.slug}</span></h3>

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
          phx-click="move_node"
          phx-target={@target}
          phx-value-node_id={@moved_node_id}
          phx-value-new_parent_id=""
          data-tip="move to top"
          icon="hero-arrow-turn-down-right-mini"
        />
      </ActionButtons.wrapper>
    </div>

    <Components.PageTree.render nodes_flat={@nodes_flat}>
      <:action_buttons :let={props}>
        <.action_buttons
          node={props.node}
          nodes_flat={@nodes_flat}
          candidates={Helpers.parent_options(@nodes_flat, @moved_node_id)}
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
        phx-value-node_id={@node.id}
        phx-value-new_parent_id={@node.id}
        phx-click="move_node"
        phx-target={@target}
        icon="hero-arrow-turn-down-right-mini"
        data-tip={ "move under #{@node.slug}" }
      />
    </ActionButtons.wrapper>
    """
  end
end
