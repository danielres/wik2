defmodule QblogWeb.PageTreeLive.Components.PagesTree do
  use QblogWeb, :live_view
  use Phoenix.Component

  alias Qblog.Wiki.PageTree.TreeQueries
  alias QblogWeb.PageTreeLive.Helpers

  attr :nodes_flat, :list, required: true
  attr :nodes_tree, :list, required: false
  attr :depth, :integer, default: 0
  slot :action_buttons, required: true

  def render(assigns) do
    assigns =
      assigns |> assign_new(:nodes_tree, fn -> assigns.nodes_flat |> TreeQueries.build_tree() end)

    ~H"""
    <ul class={[@depth == 0 and "space-y-3"]}>
      <li :for={node <- @nodes_tree} class={["card", "bg-base-100"]}>
        <.page_tree_node node={node} nodes_flat={@nodes_flat} depth={@depth + 1}>
          <:action_buttons :let={props}>
            {render_slot(@action_buttons, props)}
          </:action_buttons>
        </.page_tree_node>
      </li>
    </ul>
    """
  end

  attr :node, :map, required: true
  attr :nodes_flat, :list, required: true
  attr :depth, :integer, required: true
  slot :action_buttons, required: true

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

        {render_slot(@action_buttons, %{node: @node, depth: @depth})}
      </div>

      <.render
        :if={Helpers.has_children?(@node)}
        nodes_flat={@nodes_flat}
        nodes_tree={@node.children}
        depth={@depth}
      >
        <:action_buttons :let={props}>
          {render_slot(@action_buttons, props)}
        </:action_buttons>
      </.render>
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
end
