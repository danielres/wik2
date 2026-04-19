defmodule Qblog.Wiki.PageTree.TreeQueries do
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

  def get_child_nodes(nodes, node_id) do
    Enum.filter(nodes, &(&1.parent_id == node_id))
  end

  def get_child_nodes_with_pages(nodes, node_id) do
    nodes
    |> get_child_nodes(node_id)
    |> get_nodes_with_pages()
  end

  def get_nodes_with_pages(nodes) do
    Enum.filter(nodes, &(not is_nil(&1.page_id)))
  end

  def get_nodes_with_child_pages(nodes) do
    nodes
    |> get_nodes_with_pages()
    |> Enum.filter(&(get_child_nodes_with_pages(nodes, &1.id) != []))
  end

  def leaf?(nodes, node_id) do
    not Enum.any?(nodes, &(&1.parent_id == node_id))
  end

  def build_tree(nodes) do
    nodes
    |> root_nodes()
    |> Enum.map(&build_subtree(nodes, &1, :infinity))
  end

  def get_node_tree(nodes, source_node_id, max_depth) when is_integer(max_depth) do
    case get_node(nodes, source_node_id) do
      nil -> []
      node -> [build_subtree(nodes, node, max_depth)]
    end
  end

  def get_root_descendant_tree(nodes, max_depth) when is_integer(max_depth) do
    nodes
    |> root_nodes()
    |> Enum.map(&build_subtree(nodes, &1, max_depth))
  end

  defp build_subtree(nodes, node, depth) do
    %{
      id: node.id,
      page_id: node.page_id,
      slug: node.slug,
      title: node.title,
      children:
        if depth == 1 do
          []
        else
          child_depth = depth - 1

          nodes
          |> get_child_nodes(node.id)
          |> Enum.map(&build_subtree(nodes, &1, child_depth))
        end
    }
  end
end
