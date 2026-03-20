defmodule QblogWeb.PageTreeLive.Components.DialogMoveNode do
  use QblogWeb, :live_view
  use Phoenix.Component

  # alias Qblog.Wiki.PageTree.TreeQueries
  alias QblogWeb.PageTreeLive.Helpers

  attr :moved_node_id, :integer, default: nil
  attr :nodes_flat, :list, required: true

  def dialog(assigns) do
    assigns =
      assigns
      |> assign(
        node: assigns.nodes_flat |> Enum.find(fn node -> node.id == assigns.moved_node_id end)
      )

    ~H"""
    <dialog class={["modal", @moved_node_id != nil and "modal-open"]}>
      <div :if={@moved_node_id != nil and @node != nil} class="modal-box min-w-sm">
        <form phx-submit="move_node" class="space-y-4">
          <h3 class="">Move <span class="font-bold">node {@moved_node_id}</span> under:</h3>
          <input type="hidden" name="node_id" value={@moved_node_id} />

          <div class="card space-y-1 overflow-y-auto max-h-96">
            <button
              :if={@node.parent_id != nil}
              class="btn btn-sm"
              type="submit"
              name="new_parent_id"
              value=""
            >
              Top level
            </button>

            <button
              :for={candidate <- Helpers.parent_options(@nodes_flat, @moved_node_id)}
              class="btn btn-sm"
              type="submit"
              name="new_parent_id"
              value={candidate.id}
            >
              Node {candidate.id}
            </button>
          </div>

          <div class="modal-action">
            <.button
              phx-click="move_node_cancel"
              type="button"
              class="btn"
            >
              Cancel
            </.button>
          </div>
        </form>
      </div>
    </dialog>
    """
  end
end
