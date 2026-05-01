defmodule QblogWeb.Components.Block.Types.ChildPages.FormState do
  alias Qblog.Wiki
  alias Qblog.Wiki.PageTree

  def build(scope, current_node, selected_source_page) do
    tree_nodes = scope |> Wiki.load_page_tree() |> Map.get(:nodes, [])

    %{
      selected_source_page: selected_source_page,
      source_page_options:
        build_source_page_options(tree_nodes, current_node, selected_source_page)
    }
  end

  defp build_source_page_options(tree_nodes, current_node, selected_source_page) do
    source_page_options =
      tree_nodes
      |> PageTree.get_nodes_with_child_pages()
      |> Enum.sort_by(&PageTree.get_node_path(tree_nodes, &1.id))
      |> Enum.map(fn node ->
        {source_page_label(tree_nodes, node), "#{node.id}"}
      end)

    case selected_source_page do
      "current_page" -> [current_page_option(current_node) | source_page_options]
      _ -> source_page_options
    end
  end

  defp current_page_option(%{title: title}), do: {"#{title} (current page)", "current_page"}
  defp current_page_option(_current_node), do: {"Current page", "current_page"}

  defp source_page_label(tree_nodes, node) do
    tree_nodes
    |> PageTree.get_node_ancestors(node.id)
    |> Enum.reverse()
    |> Enum.map_join(" / ", & &1.title)
  end
end
