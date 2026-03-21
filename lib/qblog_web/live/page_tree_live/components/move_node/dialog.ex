defmodule QblogWeb.PageTreeLive.Components.MoveNode.Dialog do
  import QblogWeb.CoreComponents
  use Phoenix.Component

  alias Qblog.Wiki.PageTree.TreeQueries
  alias QblogWeb.PageTreeLive.Components
  alias QblogWeb.PageTreeLive.Components.PagesTree.ActionButtons
  alias QblogWeb.PageTreeLive.Helpers
  alias QblogWeb.PageTreeLive.Components.PagesTree

  attr :moved_node_id, :integer, default: nil
  attr :nodes_flat, :list, required: true

  def dialog(assigns) do
    assigns =
      assigns
      |> assign(
        node: assigns.nodes_flat |> Enum.find(fn node -> node.id == assigns.moved_node_id end)
      )
      |> assign(:nodes_tree, assigns.nodes_flat |> TreeQueries.build_tree())

    ~H"""
    <dialog
      phx-window-keydown="dialog_keydown_escape"
      phx-key="escape"
      class={["modal", @moved_node_id != nil and "modal-open"]}
      style="--size-field: 0.22rem;"
    >
      <div
        :if={@moved_node_id != nil and @node != nil}
        phx-click-away="move_node_cancel"
        class={[
          "modal-box",
          "min-w-sm"
        ]}
      >
        <h3 class="mb-4">Move <span class="font-bold">node {@moved_node_id}</span></h3>

        <div class={[
          "group",
          "flex items-center justify-between gap-3"
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
              phx-value-node_id={@moved_node_id}
              phx-value-new_parent_id=""
              data-tip="move to top"
              icon="hero-arrow-turn-down-right-mini"
            />
          </ActionButtons.wrapper>
        </div>

        <Components.PagesTree.render nodes_flat={@nodes_flat} depth={1}>
          <:action_buttons :let={props}>
            <.action_buttons
              node={props.node}
              nodes_flat={@nodes_flat}
              candidates={Helpers.parent_options(@nodes_flat, @moved_node_id)}
            />
          </:action_buttons>
        </Components.PagesTree.render>

        <div class="modal-action">
          <.button
            phx-click="move_node_cancel"
            type="button"
            class="btn"
          >
            Cancel
          </.button>
        </div>
      </div>
    </dialog>
    """
  end

  attr :candidates, :list, required: true
  attr :node, :map, required: true
  attr :nodes_flat, :list, required: true

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
        icon="hero-arrow-turn-down-right-mini"
        data-tip={ "move under #{@node.id}" }
      />
    </ActionButtons.wrapper>
    """
  end
end
