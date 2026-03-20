defmodule QblogWeb.PageTreeLive.Components.PagesTree do
  use QblogWeb, :live_view
  use Phoenix.Component

  alias Qblog.Wiki.PageTree.TreeQueries
  alias QblogWeb.PageTreeLive.Helpers

  attr :nodes_flat, :list, required: true
  attr :nodes_tree, :list, required: false
  attr :depth, :integer, default: 0

  def render(assigns) do
    assigns =
      assigns |> assign_new(:nodes_tree, fn -> assigns.nodes_flat |> TreeQueries.build_tree() end)

    ~H"""
    <ul class={[@depth == 0 and "space-y-3"]}>
      <li :for={node <- @nodes_tree} class={["card", "bg-base-100"]}>
        <.page_tree_node node={node} nodes_flat={@nodes_flat} depth={@depth + 1}>
          <.action_buttons node={node} nodes_flat={@nodes_flat} depth={@depth + 1} />
        </.page_tree_node>
      </li>
    </ul>
    """
  end

  attr :node, :map, required: true
  attr :nodes_flat, :list, required: true
  attr :depth, :integer, required: true
  slot :inner_block, required: true

  defp page_tree_node(assigns) do
    ~H"""
    <.page_tree_node_wrapper depth={@depth} has_children?={Helpers.has_children?(@node)}>
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

        {render_slot(@inner_block, %{node: @node})}
      </div>

      <.render
        :if={Helpers.has_children?(@node)}
        nodes_flat={@nodes_flat}
        nodes_tree={@node.children}
        depth={@depth}
      />
    </.page_tree_node_wrapper>
    """
  end

  defp page_tree_node_label(assigns) do
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

  defp icon_chevron(assigns) do
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

  attr :depth, :integer, required: true
  attr :has_children?, :boolean, required: true
  slot :inner_block, required: true

  defp page_tree_node_wrapper(assigns) do
    ~H"""
    <div
      class={[
        "card-body",
        @depth > 1 and "py-1",
        @depth > 1 and "pr-0",
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
  attr :depth, :integer, required: true

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
      <.action_button
        :if={@node.children == []}
        phx-value-node_id={@node.id}
        phx-click="remove_node"
        icon="hero-x-mark-mini"
        data-tip="delete"
        variant="error"
      />

      <.action_button
        :if={@has_candidates?}
        phx-value-node_id={@node.id}
        phx-click="move_node_start"
        icon="hero-arrow-turn-down-right-mini"
        data-tip="move"
      />

      <.action_button
        phx-value-node_id={@node.id}
        phx-click="add_child"
        icon="hero-plus-mini"
        data-tip="add child"
      />
    </div>
    """
  end

  attr :variant, :string, default: "primary"
  attr :"phx-value-node_id", :integer, required: true
  attr :"phx-click", :string, required: true
  attr :"data-tip", :string, required: true
  attr :icon, :string, required: true

  defp action_button(assigns) do
    class =
      case assigns.variant do
        "error" -> "hover:btn-error"
        _ -> "hover:btn-primary"
      end

    assigns = assigns |> assign(class: class)

    ~H"""
    <.button
      class={[
        "btn btn-xs btn-circle",
        "tooltip",
        @class
      ]}
      {assigns}
    >
      <.icon name={@icon} />
      <span class="sr-only">{assigns[:"data-tip"]}</span>
    </.button>
    """
  end
end
