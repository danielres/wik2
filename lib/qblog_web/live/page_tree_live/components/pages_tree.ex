defmodule QblogWeb.PageTreeLive.Components.PagesTree do
  use QblogWeb, :live_view
  use Phoenix.Component

  alias Qblog.Wiki.PageTree.TreeQueries
  alias QblogWeb.PageTreeLive.Helpers

  attr :nodes_flat, :list, required: true

  def render(assigns) do
    nodes_tree = assigns.nodes_flat |> TreeQueries.build_tree()
    assigns = assigns |> assign(nodes_tree: nodes_tree)

    ~H"""
    <.page_tree_list nodes_flat={@nodes_flat} nodes_tree={@nodes_tree} root?={true} />
    """
  end

  attr :root?, :boolean, required: true
  attr :nodes_flat, :list, required: true
  attr :nodes_tree, :list, required: true

  def page_tree_list(assigns) do
    ~H"""
    <ul class={[@root? and "space-y-3"]}>
      <li :for={node <- @nodes_tree} class={["card", "bg-base-100"]}>
        <.page_tree_node node={node} root?={@root?} nodes_flat={@nodes_flat} />
      </li>
    </ul>
    """
  end

  attr :node, :map, required: true
  attr :nodes_flat, :list, required: true
  attr :root?, :boolean, default: false

  def page_tree_node(assigns) do
    ~H"""
    <.page_tree_node_wrapper root?={@root?} has_children?={Helpers.has_children?(@node)}>
      <div class={[
        "group",
        "flex items-center justify-between gap-3"
      ]}>
        <.page_tree_node_label
          node={@node}
          class={[
            "opacity-80 group-has-[button:hover]:opacity-100",
            "transition"
          ]}
        />

        <.action_buttons root?={@root?} node={@node} nodes_flat={@nodes_flat} />
      </div>

      <%= if Helpers.has_children?(@node) do %>
        <.page_tree_list nodes_tree={@node.children} root?={false} nodes_flat={@nodes_flat} />
      <% end %>
    </.page_tree_node_wrapper>
    """
  end

  def page_tree_node_label(assigns) do
    ~H"""
    <div class={["flex gap-2", @class]}>
      <div class="flex">
        <.icon_chevron /> Node {@node.id}
      </div>

      <div class="opacity-60">
        {if @node.page_id, do: "page: #{@node.page_id}", else: "no page"}
      </div>
    </div>
    """
  end

  def icon_chevron(assigns) do
    ~H"""
    <.icon
      name="hero-chevron-right-mini"
      class={[
        "rotate-135",
        "group-has-[button:hover]:rotate-0",
        "opacity-30",
        "group-has-[button:hover]:opacity-100",
        "transition"
      ]}
    />
    """
  end

  attr :node, :map, required: true
  attr :root?, :boolean, default: false
  slot :inner_block, required: true

  def page_tree_node_wrapper(assigns) do
    ~H"""
    <div
      class={[
        "card-body",
        !@root? and "py-1",
        !@root? and "pr-0",
        @has_children? and "pb-2"
      ]}
      style="--size-field: 0.22rem;"
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :node, :map, required: true
  attr :nodes_flat, :list, required: true
  attr :root?, :boolean, default: false

  defp action_buttons(assigns) do
    candidates = Helpers.parent_options(assigns.nodes_flat, assigns.node.id)
    assigns = assigns |> assign(has_candidates?: candidates |> Enum.count() > 0)

    ~H"""
    <div class={[
      "flex flex-wrap gap-2",
      "[&_button]:opacity-50",
      "[&_button]:hover:opacity-100",
      "[&_button]:transition"
    ]}>
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
    </div>
    """
  end
end
