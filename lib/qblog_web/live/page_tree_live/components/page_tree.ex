defmodule QblogWeb.PageTreeLive.Components.PageTree do
  use QblogWeb, :live_view
  use Phoenix.Component

  alias Qblog.Wiki.PageTree.TreeQueries
  alias QblogWeb.PageTreeLive.Helpers

  def render(assigns) do
    ~H"""
    <%= if @nodes_flat == [] do %>
      <div class="card bg-base-100 shadow">
        <div class="card-body">
          No nodes yet.
        </div>
      </div>
    <% else %>
      <.page_tree_nodes {assigns} />
    <% end %>
    """
  end

  attr :depth, :integer, default: 0
  attr :nodes_flat, :list, required: true
  attr :nodes_tree, :list, required: false
  slot :action_buttons, required: false
  slot :label, required: false

  def page_tree_nodes(assigns) do
    assigns =
      assigns
      |> assign_new(:nodes_tree, fn ->
        assigns.nodes_flat

        # TODO: change &1.slug to &1.title
        |> Enum.sort_by(&(&1.slug |> String.downcase()), :asc)
        |> TreeQueries.build_tree()
      end)

    ~H"""
    <ul class={[@depth == 0 and "space-y-3"]}>
      <li
        :for={node <- @nodes_tree}
        class={["card", "bg-base-100"]}
        data-testid={"page-tree-node-#{node.id}"}
      >
        <.page_tree_node node={node} nodes_flat={@nodes_flat} depth={@depth + 1}>
          <:action_buttons :let={props}>
            {render_slot(@action_buttons, props)}
          </:action_buttons>

          <:label :let={props}>
            {render_slot(@label, props)}
          </:label>
        </.page_tree_node>
      </li>
    </ul>
    """
  end

  attr :depth, :integer, required: true
  attr :node, :map, required: true
  attr :nodes_flat, :list, required: true
  slot :action_buttons, required: true
  slot :label, required: true

  defp page_tree_node(assigns) do
    ~H"""
    <.node_wrapper depth={@depth} has_children?={Helpers.has_children?(@node)}>
      <div class={[
        "group",
        "flex items-center justify-between gap-3"
      ]}>
        <div class={[
          "flex gap-2",
          "opacity-80 group-has-[button:hover]:opacity-100",
          "transition"
        ]}>
          <div class="flex">
            <.icon_chevron />
          </div>

          {render_slot(@label, %{node: @node})}
        </div>

        {render_slot(@action_buttons, %{node: @node, depth: @depth})}
      </div>

      <.page_tree_nodes
        :if={Helpers.has_children?(@node)}
        nodes_flat={@nodes_flat}
        nodes_tree={@node.children}
        depth={@depth}
      >
        <:action_buttons :let={props}>
          {render_slot(@action_buttons, props)}
        </:action_buttons>
        <:label :let={props}>
          {render_slot(@label, props)}
        </:label>
      </.page_tree_nodes>
    </.node_wrapper>
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

  def node_wrapper(assigns) do
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
