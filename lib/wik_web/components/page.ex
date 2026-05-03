defmodule WikWeb.Components.Page do
  use WikWeb, :html

  alias Wik.Wiki.PageTree

  attr :include_current?, :boolean, default: true
  attr :node, :map, required: true
  attr :page_tree, :map, required: true
  attr :scope, :map, required: true
  attr :trailing_separator?, :boolean, default: false
  attr :class, :any, default: ""

  def breadcrumbs(assigns) do
    path = breadcrumb_path(assigns.page_tree, assigns.node)

    assigns =
      assigns
      |> assign(:items, breadcrumb_items(assigns.page_tree, path, assigns.include_current?))

    ~H"""
    <div :if={@items != []} class={["flex items-center gap-1", @class]}>
      <nav class="breadcrumbs p-0">
        <ul>
          <li :for={item <- @items}>
            <.link
              class="opacity-70 hover:opacity-100 transition-opacity"
              navigate={build_page_path(@scope, item.path)}
            >
              {item.title}
            </.link>
          </li>

          <li :if={@trailing_separator?} class=""></li>
        </ul>
      </nav>
    </div>
    """
  end

  def breadcrumb_items(page_tree, path, include_current? \\ true)
  def breadcrumb_items(%PageTree{}, nil, _include_current?), do: []

  def breadcrumb_items(%PageTree{nodes: nodes}, path, include_current?)
      when is_binary(path) do
    path
    |> path_prefixes()
    |> then(fn items ->
      if include_current?, do: items, else: Enum.drop(items, -1)
    end)
    |> Enum.map(fn prefix ->
      case PageTree.get_node_by_path(nodes, prefix) do
        {:ok, node} ->
          %{
            node_id: node.id,
            path: prefix,
            title: node.title
          }

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp build_page_path(%{tenant: tenant}, path) do
    "/" <> tenant.name <> "/wiki" <> "/" <> path
  end

  defp breadcrumb_path(%PageTree{}, %{path: path}) when is_binary(path), do: path

  defp breadcrumb_path(%PageTree{nodes: nodes}, %{id: id}),
    do: PageTree.get_node_path(nodes, id)

  defp breadcrumb_path(%PageTree{nodes: nodes}, %{node_id: node_id}),
    do: PageTree.get_node_path(nodes, node_id)

  defp path_prefixes(path) do
    path
    |> String.split("/", trim: true)
    |> Enum.reduce({[], ""}, fn segment, {prefixes, current} ->
      prefix =
        case current do
          "" -> segment
          current -> current <> "/" <> segment
        end

      {prefixes ++ [prefix], prefix}
    end)
    |> elem(0)
  end
end
