defmodule QblogWeb.PageTreeLive.Components.MoveNode.Dialog do
  use QblogWeb, :live_view
  use Phoenix.Component

  alias Qblog.Wiki.PageTree.TreeQueries
  alias QblogWeb.PageTreeLive.Helpers
  alias QblogWeb.PageTreeLive.Components

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
        class="modal-box min-w-sm"
        phx-click-away="move_node_cancel"
      >
        <h3 class="">Move <span class="font-bold">node {@moved_node_id}</span> under:</h3>

        <form phx-submit="move_node" class="space-y-4">
          <input type="hidden" name="node_id" value={@moved_node_id} />

          <div class={[
            "group",
            "flex items-center justify-between gap-3"
          ]}>
            <div class={[
              "flex gap-2",
              "opacity-80",
              "group-has-[button:hover]:opacity-100",
              "transition"
            ]}>
              <div class="text-sm">
                Top level
              </div>
            </div>

            <div class={[
              "flex flex-wrap gap-2",
              "[&_button]:opacity-50",
              "[&_button]:hover:opacity-100",
              "[&_button]:transition"
            ]}>
              <button
                class={[
                  "btn btn-xs btn-circle hover:btn-primary",
                  "tooltip",
                  "tooltip-left"
                ]}
                type="submit"
                name="new_parent_id"
                value=""
              >
                <.icon name="hero-arrow-turn-down-right-mini" />
                <span class="sr-only">
                  Move
                </span>
              </button>
            </div>
          </div>
        </form>

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
