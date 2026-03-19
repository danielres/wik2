defmodule QblogWeb.PageTreeLive.Components do
  use QblogWeb, :live_view
  use Phoenix.Component

  alias QblogWeb.PageTreeLive.Helpers

  attr :nodes, :list, required: true
  attr :flat_nodes, :list, required: true
  attr :root?, :boolean, default: true

  def page_tree_nodes(assigns) do
    ~H"""
    <ul class={[@root? and "space-y-3"]}>
      <%= for node <- @nodes do %>
        <.page_tree_node node={node} root?={@root?} flat_nodes={@flat_nodes} />
      <% end %>
    </ul>
    """
  end

  attr :node, :map, required: true
  attr :flat_nodes, :list, required: true
  attr :root?, :boolean, default: false

  def page_tree_node(assigns) do
    ~H"""
    <li class={[
      "card bg-base-100"
    ]}>
      <div class={[
        "card-body",
        !@root? and "py-1",
        !@root? and "pr-0",
        Helpers.has_children?(@node) and "pb-2"
      ]}>
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
            <div class="flex">
              <.icon
                name="hero-chevron-right-mini"
                class={[
                  "rotate-135",
                  "group-has-[button:hover]:rotate-0",
                  "opacity-30",
                  "group-has-[button:hover]:opacity-100",
                  "transition"
                ]}
              /> Node {@node.id}
            </div>
            <div class="opacity-60">
              <%= if @node.page_id do %>
                page: {@node.page_id}
              <% else %>
                no page
              <% end %>
            </div>
          </div>

          <div
            class={[
              "flex flex-wrap gap-2",
              "[&_button]:opacity-50",
              "[&_button]:hover:opacity-100",
              "[&_button]:transition"
            ]}
            style="--size-field: 0.22rem;"
          >
            <.action_buttons root?={@root?} node={@node} flat_nodes={@flat_nodes} />
          </div>
        </div>

        <%= if Helpers.has_children?(@node) do %>
          <.page_tree_nodes nodes={@node.children} root?={false} flat_nodes={@flat_nodes} />
        <% end %>
      </div>
    </li>
    """
  end

  attr :node, :map, required: true
  attr :flat_nodes, :list, required: true
  attr :root?, :boolean, default: false

  defp action_buttons(assigns) do
    ~H"""
    <.button
      :if={@node.children == []}
      phx-click="remove_node"
      phx-value-node_id={@node.id}
      class={[
        "btn btn-xs btn-circle hover:btn-error",
        "tooltip"
      ]}
      data-tip="delete"
    >
      <.icon name="hero-x-mark-mini" />
      <span class="sr-only">Delete</span>
    </.button>

    <.button
      phx-click={JS.add_class("modal-open", to: "#move-node-#{@node.id}")}
      class={["btn btn-xs btn-circle hover:btn-primary", "tooltip"]}
      data-tip="move"
    >
      <.icon name="hero-arrow-turn-down-right-mini" />
      <span class="sr-only">
        Move
      </span>
    </.button>

    <dialog id={"move-node-#{@node.id}"} class="modal xmodal-open">
      <div class="modal-box min-w-sm">
        <form
          phx-submit={
            JS.remove_class("modal-open", to: {:closest, "dialog"})
            |> JS.push("move_node")
          }
          class="space-y-4"
        >
          <h3 class="">Move <span class="font-bold">node {@node.id}</span> under:</h3>

          <input type="hidden" name="node_id" value={@node.id} />

          <div class="card space-y-1 overflow-y-auto max-h-96">
            <button :if={!@root?} class="btn btn-sm" type="submit" name="new_parent_id" value="">
              Top level
            </button>
            <button
              :for={candidate <- Helpers.parent_options(@flat_nodes, @node.id)}
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
              phx-click={JS.remove_class("modal-open", to: "#move-node-#{@node.id}")}
              type="button"
              class="btn"
            >
              Cancel
            </.button>

            <.button type="submit" class="btn btn-primary">Move</.button>
          </div>
        </form>
      </div>
    </dialog>

    <.button
      phx-click="add_child"
      phx-value-node_id={@node.id}
      class={[
        "btn btn-xs btn-circle hover:btn-primary",
        "tooltip"
      ]}
      data-tip="add child"
    >
      <.icon name="hero-plus-mini" />
      <span class="sr-only">Add child</span>
    </.button>
    """
  end
end
