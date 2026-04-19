defmodule QblogWeb.Components.Block.Types.ChildPages.RenderState do
  alias Qblog.Wiki
  alias Qblog.Wiki.PageTree.TreeQueries

  def build(scope, current_node, current_path, block_data) do
    tree_nodes = scope |> Wiki.load_page_tree() |> Map.get(:nodes, [])

    case resolve_source(tree_nodes, current_node, current_path, block_data) do
      :no_source ->
        %{child_nodes: [], source_node_missing?: false, source_page: nil}

      :missing_source_node ->
        %{child_nodes: [], source_node_missing?: true, source_page: nil}

      {:source, source_node, source_page} ->
        %{
          child_nodes:
            tree_nodes
            |> TreeQueries.get_child_nodes_with_pages(source_node.id)
            |> Enum.map(&display_node(&1, tree_nodes)),
          source_node_missing?: false,
          source_page: source_page
        }
    end
  end

  defp resolve_source(tree_nodes, _current_node, _current_path, %{
         "source" => "node",
         "node_id" => node_id
       }) do
    case TreeQueries.get_node(tree_nodes, node_id) do
      nil -> :missing_source_node
      source_node -> {:source, source_node, display_node(source_node, tree_nodes)}
    end
  end

  defp resolve_source(_tree_nodes, nil, _current_path, _block_data), do: :no_source

  defp resolve_source(_tree_nodes, current_node, current_path, %{"source" => "current_page"})
       when not is_nil(current_node) and is_binary(current_path) and current_path != "" do
    {:source, current_node, %{path: current_path, title: current_node.title}}
  end

  defp resolve_source(tree_nodes, current_node, _current_path, _block_data) do
    {:source, current_node, display_node(current_node, tree_nodes)}
  end

  defp display_node(node, tree_nodes) do
    %{
      node_id: node.id,
      path: TreeQueries.get_node_path(tree_nodes, node.id),
      title: node.title
    }
  end
end
