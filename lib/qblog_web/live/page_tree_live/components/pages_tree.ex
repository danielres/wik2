defmodule QblogWeb.PageTreeLive.Components.PagesTree do
  use QblogWeb, :live_view
  use Phoenix.Component

  alias Qblog.Wiki.PageTree.TreeQueries
  alias QblogWeb.PageTreeLive.Helpers

  def render(assigns), do: page_tree_nodes(assigns)

  attr :root?, :boolean, default: true
  attr :nodes_flat, :list, required: true
  attr :nodes_tree, :list, required: false

  def page_tree_nodes(assigns) do
    assigns =
      assigns
      |> assign_new(:nodes_tree, fn -> assigns.nodes_flat |> TreeQueries.build_tree() end)

    ~H"""
    <ul class={[@root? and "space-y-3"]}>
      <%= for node <- @nodes_tree do %>
        <.page_tree_node node={node} root?={@root?} nodes_flat={@nodes_flat} />
      <% end %>
    </ul>
    """
  end

  attr :node, :map, required: true
  attr :nodes_flat, :list, required: true
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
            <.action_buttons root?={@root?} node={@node} nodes_flat={@nodes_flat} />
          </div>
        </div>

        <%= if Helpers.has_children?(@node) do %>
          <.page_tree_nodes nodes_tree={@node.children} root?={false} nodes_flat={@nodes_flat} />
        <% end %>
      </div>
    </li>
    """
  end

  attr :node, :map, required: true
  attr :nodes_flat, :list, required: true
  attr :root?, :boolean, default: false

  defp action_buttons(assigns) do
    candidates = Helpers.parent_options(assigns.nodes_flat, assigns.node.id)
    assigns = assigns |> assign(has_candidates?: candidates |> Enum.count() > 0)

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
      :if={@has_candidates?}
      phx-click="move_node_start"
      phx-value-node_id={@node.id}
      class={["btn btn-xs btn-circle hover:btn-primary", "tooltip"]}
      data-tip="move"
    >
      <.icon name="hero-arrow-turn-down-right-mini" />
      <span class="sr-only">
        Move
      </span>
    </.button>

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
