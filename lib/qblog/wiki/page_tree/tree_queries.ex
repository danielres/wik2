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
end
