defmodule QblogWeb.Components.Page do
  use QblogWeb, :html

  alias Qblog.Wiki.PageTree
  alias Qblog.Wiki.PageTree.TreeQueries

  attr :include_current?, :boolean, default: true
  attr :node, :map, required: true
  attr :page_tree, :map, required: true
  attr :scope, :map, required: true
  attr :class, :any, default: ""

  def breadcrumbs(assigns) do
    node_id = assigns.node[:id] || assigns.node[:node_id]

    assigns =
      assigns
      |> assign(:items, breadcrumb_items(assigns.page_tree, node_id, assigns.include_current?))

    ~H"""
    <nav :if={@items != []} class={["breadcrumbs p-0", @class]}>
      <ul>
        <li :for={item <- @items}>
          <.link
            class={[
              "opacity-70 hover:opacity-100 transition-opacity"
            ]}
            navigate={build_page_path(@scope, item.path)}
          >
            {item.title}
          </.link>
        </li>
      </ul>
    </nav>
    """
  end

  def breadcrumb_items(%PageTree{nodes: nodes}, node_id, include_current? \\ true) do
    nodes
    |> TreeQueries.get_node_ancestors(node_id)
    |> Enum.reverse()
    |> then(fn items ->
      if include_current?, do: items, else: Enum.drop(items, -1)
    end)
    |> Enum.filter(&(not is_nil(&1.page_id)))
    |> Enum.map(fn node ->
      %{
        node_id: node.id,
        path: TreeQueries.get_node_path(nodes, node.id),
        title: node.title
      }
    end)
  end

  defp build_page_path(%{tenant: tenant}, path) do
    "/" <> tenant.name <> "/wiki" <> "/" <> path
  end
end
