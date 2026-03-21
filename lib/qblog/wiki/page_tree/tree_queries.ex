defmodule Qblog.Wiki.PageTree.TreeQueries do
  def get_node(nodes, node_id) do
    Enum.find(nodes, &(&1.id == node_id))
  end

  def root_nodes(nodes) do
    Enum.filter(nodes, &is_nil(&1.parent_id))
  end

  def child_nodes(nodes, node_id) do
    Enum.filter(nodes, &(&1.parent_id == node_id))
  end

  def leaf?(nodes, node_id) do
    not Enum.any?(nodes, &(&1.parent_id == node_id))
  end

  def build_tree(nodes) do
    nodes
    |> root_nodes()
    |> Enum.map(&build_subtree(nodes, &1))
  end

  defp build_subtree(nodes, node) do
    %{
      id: node.id,
      page_id: node.page_id,
      slug: node.slug,
      children:
        nodes
        |> child_nodes(node.id)
        |> Enum.map(&build_subtree(nodes, &1))
    }
  end
end
