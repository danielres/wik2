defmodule QblogWeb.PageTreeLive.Components.MoveNode do
  use Phoenix.Component

  alias QblogWeb.PageTreeLive.Components
  alias QblogWeb.PageTreeLive.Components.PageTree.ActionButtons
  alias QblogWeb.PageTreeLive.Helpers

  attr :moved_node_id, :integer, default: nil
  attr :nodes_flat, :list, required: true
  attr :target, :any, required: true

  def dialog(assigns) do
    candidates = assigns.nodes_flat |> Helpers.parent_options(assigns.moved_node_id)

    assigns =
      assigns
      |> assign(candidates: candidates)
      |> assign(can_move_to_top?: Enum.any?(candidates, &is_nil(&1.id)))

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

      <ActionButtons.wrapper :if={@can_move_to_top?}>
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
          candidates={@candidates}
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
      <%!-- TODO: change @node.slug to @node.title --%>
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
