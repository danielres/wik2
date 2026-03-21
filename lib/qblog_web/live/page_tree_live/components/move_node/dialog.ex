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

        <Components.MoveNode.Selector.page_tree_nodes
          root?={false}
          nodes_flat={@nodes_flat}
          nodes_tree={@nodes_tree}
          candidates={Helpers.parent_options(@nodes_flat, @moved_node_id)}
        />

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
end
