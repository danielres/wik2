defmodule Qblog.Wiki.PageTree.TreeQueries do
  alias Qblog.Wiki.PageTree
  alias Qblog.Wiki.PageTree.TreeQueries.GetNodeByPath
  alias Utils.Log

  def get_node(nodes, node_id) do
    Enum.find(nodes, &(&1.id == node_id))
  end

  def get_node_by_path(nodes, path) when is_binary(path) do
    nodes
    |> get_node_by_path(String.split(path, "/", trim: true))
  end

  def get_node_by_path(nodes, path) when is_list(path) do
    case Enum.reduce_while(path, nil, fn slug, parent_id ->
           case find_node_by_slug_and_parent_id(nodes, slug, parent_id) do
             nil -> {:halt, :not_found}
             node -> {:cont, node.id}
           end
         end) do
      :not_found ->
        {:error, :not_found}

      nil ->
        {:error, :not_found}

      node_id ->
        {:ok, get_node(nodes, node_id)}
    end
  end

  defp find_node_by_slug_and_parent_id(nodes, slug, parent_id) do
    Enum.find(nodes, &(&1.slug == slug and &1.parent_id == parent_id))
  end

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
    case PageTree.ensure(scope: scope) do
      {:ok, page_tree} ->
        page_tree

      {:error, err} ->
        Log.scoped_error(scope, err, "PageTree.ensure failed")
        %PageTree{nodes: []}
    end
  end
end
