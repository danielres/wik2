defmodule QblogWeb.PageTreeLive.Components.MoveNode.Selector do
  use QblogWeb, :live_view
  use Phoenix.Component

  alias Qblog.Wiki.PageTree.TreeQueries
  alias QblogWeb.PageTreeLive.Helpers

  attr :root?, :boolean, default: true
  attr :nodes_flat, :list, required: true
  attr :nodes_tree, :list, required: false
  attr :candidates, :list, required: true

  def page_tree_nodes(assigns) do
    assigns =
      assigns
      |> assign_new(:nodes_tree, fn -> assigns.nodes_flat |> TreeQueries.build_tree() end)

    ~H"""
    <ul class={[@root? and "space-y-3"]}>
      <.page_tree_node
        :for={node <- @nodes_tree}
        node={node}
        root?={@root?}
        nodes_flat={@nodes_flat}
        candidates={@candidates}
      />
    </ul>
    """
  end

  attr :node, :map, required: true
  attr :nodes_flat, :list, required: true
  attr :root?, :boolean, default: false
  attr :candidates, :list, required: true

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

          <div class={[
            "flex flex-wrap gap-2",
            "[&_button]:opacity-50",
            "[&_button]:hover:opacity-100",
            "[&_button]:transition"
          ]}>
            <.action_buttons
              root?={@root?}
              node={@node}
              nodes_flat={@nodes_flat}
              candidates={@candidates}
            />
          </div>
        </div>

        <.page_tree_nodes
          :if={Helpers.has_children?(@node)}
          candidates={@candidates}
          nodes_tree={@node.children}
          root?={false}
          nodes_flat={@nodes_flat}
        />
      </div>
    </li>
    """
  end

  attr :node, :map, required: true
  attr :nodes_flat, :list, required: true
  attr :root?, :boolean, default: false

  defp action_buttons(assigns) do
    candidate_ids = assigns.candidates |> Enum.map(fn e -> e.id end)
    candidate? = assigns.node.id in candidate_ids
    assigns = assigns |> assign(candidate?: candidate?)

    ~H"""
    <form phx-submit="move_node" class="space-y-4">
      <div class="card space-y-1 overflow-y-auto max-h-96">
        <button
          :if={@candidate?}
          class={["btn btn-xs btn-circle hover:btn-primary", "tooltip", "tooltip-left"]}
          data-tip={ "move under #{@node.id}" }
          type="submit"
          name="new_parent_id"
          value={@node.id}
        >
          <.icon name="hero-arrow-turn-down-right-mini" />
          <span class="sr-only">
            Move
          </span>
        </button>
      </div>
    </form>
    """
  end
end
