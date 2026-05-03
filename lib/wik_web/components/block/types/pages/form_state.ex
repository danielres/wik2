defmodule WikWeb.Components.Block.Types.Pages.FormState do
  alias Wik.Wiki
  alias Wik.Wiki.PageTree

  def build(scope, selected_source_node) do
    tree_nodes = scope |> Wiki.load_page_tree() |> Map.get(:nodes, [])

    %{
      selected_source_node: selected_source_node,
      source_node_options: source_node_options(tree_nodes)
    }
  end

  defp source_node_options(tree_nodes) do
    source_node_options =
      tree_nodes
      |> Enum.filter(&(PageTree.get_child_nodes(tree_nodes, &1.id) != []))
      |> Enum.sort_by(&PageTree.get_node_path(tree_nodes, &1.id))
      |> Enum.map(fn node ->
        {source_node_label(tree_nodes, node), "#{node.id}"}
      end)

    [{"Root", "root"} | source_node_options]
  end

  defp source_node_label(tree_nodes, node) do
    tree_nodes
    |> PageTree.get_node_ancestors(node.id)
    |> Enum.reverse()
    |> Enum.map_join(" / ", & &1.title)
  end
end
