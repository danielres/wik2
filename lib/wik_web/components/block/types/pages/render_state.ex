defmodule WikWeb.Components.Block.Types.Pages.RenderState do
  alias Wik.Wiki
  alias Wik.Wiki.PageTree

  def build(scope, %{"depth" => depth, "source_node" => source_node}) do
    tree_nodes = scope |> Wiki.load_page_tree() |> Map.get(:nodes, [])

    case source_tree(tree_nodes, source_node, depth) do
      :missing_source_node ->
        %{source_node_missing?: true, tree: []}

      tree ->
        %{
          source_node_missing?: false,
          tree: Enum.map(tree, &display_node(&1, tree_nodes))
        }
    end
  end

  defp source_tree(tree_nodes, "root", depth) do
    PageTree.get_root_descendant_tree(tree_nodes, depth)
  end

  defp source_tree(tree_nodes, source_node_id, depth) when is_integer(source_node_id) do
    case PageTree.get_node(tree_nodes, source_node_id) do
      nil -> :missing_source_node
      _source_node -> PageTree.get_node_tree(tree_nodes, source_node_id, depth)
    end
  end

  defp display_node(node, tree_nodes) do
    %{
      children: Enum.map(node.children, &display_node(&1, tree_nodes)),
      node_id: node.id,
      path: PageTree.get_node_path(tree_nodes, node.id),
      title: node.title
    }
  end
end
