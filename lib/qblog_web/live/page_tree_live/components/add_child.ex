defmodule QblogWeb.PageTreeLive.Components.AddChild do
  import QblogWeb.CoreComponents
  use Phoenix.Component

  attr :open?, :boolean, required: true
  attr :parent_id, :integer, default: nil
  attr :nodes_flat, :list, required: true
  attr :target, :any, required: true
  attr :scope, :map, required: true
  attr :form, :any, required: true

  def dialog(assigns) do
    assigns =
      assigns
      |> assign(
        parent_node: assigns.nodes_flat |> Enum.find(fn node -> node.id == assigns.parent_id end)
      )

    # TODO: extract dialog to own component
    ~H"""
    <dialog
      class={["modal", @open? and "modal-open"]}
      phx-key="escape"
      phx-target={@target}
      phx-window-keydown="dialog_keydown_escape"
      style="--size-field: 0.22rem;"
    >
      <div
        :if={@open?}
        class={["modal-box", "min-w-sm"]}
        phx-click-away="add_child_cancel"
        phx-target={@target}
      >
        <h3 class="mb-4">
          Add child under
          <span class="font-bold">
            {if @parent_node, do: @parent_node.slug, else: "top level"}
          </span>
        </h3>

        <.form
          for={@form}
          phx-change="validate_child"
          phx-submit="add_child"
          phx-target={@target}
        >
          <div class="card bg-base-300">
            <div class="card-body">
              <.input
                field={@form[:parent_id]}
                type="hidden"
                value={@parent_id}
              />
              <.input
                field={@form[:slug]}
                label="slug"
              />
              <.button
                class="btn btn-primary mt-3"
                type="submit"
              >
                Create post
              </.button>
            </div>
          </div>
        </.form>

        <%!-- TODO: replace with top right x button --%>
        <div class="modal-action">
          <.button
            class="btn"
            phx-click="add_child_cancel"
            phx-target={@target}
            type="button"
          >
            Cancel
          </.button>
        </div>
      </div>
    </dialog>
    """
  end
end
