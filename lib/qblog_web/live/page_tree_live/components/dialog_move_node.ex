defmodule QblogWeb.PageTreeLive.Components.DialogMoveNode do
  use QblogWeb, :live_view
  use Phoenix.Component

  alias Qblog.Wiki.PageTree.TreeQueries
  alias QblogWeb.PageTreeLive.Helpers

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
      phx-window-keydown="dialog_keydown"
      class={["modal", @moved_node_id != nil and "modal-open"]}
    >
      <div
        :if={@moved_node_id != nil and @node != nil}
        class="modal-box min-w-sm"
        phx-click-away="move_node_cancel"
      >
        <h3 class="">Move <span class="font-bold">node {@moved_node_id}</span> under:</h3>

        <form :if={@node.parent_id != nil} phx-submit="move_node" class="space-y-4">
          <input type="hidden" name="node_id" value={@moved_node_id} />

          <div class="card space-y-1 overflow-y-auto max-h-96">
            <button
              class="btn btn-sm"
              type="submit"
              name="new_parent_id"
              value=""
            >
              Top level
            </button>
          </div>
        </form>

        <QblogWeb.PageTreeLive.Components.Selector.page_tree_nodes
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
