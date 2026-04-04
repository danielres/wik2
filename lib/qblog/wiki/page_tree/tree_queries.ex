defmodule Qblog.Wiki.PageTree.TreeQueries do
  alias Qblog.Wiki.PageTree
  alias Qblog.Wiki.PageTree.TreeQueries.ByPath.Get
  alias Utils.Log

  def get_node(nodes, node_id) do
    Enum.find(nodes, &(&1.id == node_id))
  end

  defdelegate get_node_by_path(nodes, path), to: Get, as: :call

  def root_nodes(nodes) do
    Enum.filter(nodes, &is_nil(&1.parent_id))
  end

  def get_node_parent(nodes, node_id) do
    case get_node(nodes, node_id) do
      nil -> nil
      node -> get_node(nodes, node.parent_id)
    end
  end

  def get_node_ancestors(nodes, node_id) do
    case get_node(nodes, node_id) do
      nil -> []
      node -> [node | get_node_ancestors(nodes, node.parent_id)]
    end
  end

  def get_node_path_segments(nodes, node_id) do
    get_node_ancestors(nodes, node_id)
    |> Enum.reverse()
    |> Enum.map(& &1.slug)
  end

  def get_node_path(nodes, node_id) do
    get_node_path_segments(nodes, node_id) |> Enum.join("/")
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
      title: node.title,
      children:
        nodes
        |> child_nodes(node.id)
        |> Enum.map(&build_subtree(nodes, &1))
    }
  end

  def load_node_by_path(scope, path) do
    page_tree = scope |> load_page_tree()

    case get_node_by_path(page_tree.nodes, path) do
      {:ok, node} ->
        node

      {:error, _err} ->
        nil
    end
  end

  defp load_page_tree(scope) do
    case PageTree.ensure_page_tree(scope: scope) do
      {:ok, page_tree} ->
        page_tree

      {:error, err} ->
        Log.scoped_error(scope, err, "ensure_page_tree failed")
        %PageTree{nodes: []}
    end
  end
end
