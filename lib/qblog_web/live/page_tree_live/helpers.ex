defmodule QblogWeb.PageTreeLive.Helpers do
  def get_node_by_id(_nodes_flat, nil) do
    %{slug: "top", title: "Top", id: nil}
  end

  def get_node_by_id(nodes_flat, id) do
    nodes_flat |> Enum.find(fn node -> node.id == id end)
  end

  def node_path(nodes_flat, node_id) do
    case get_node_by_id(nodes_flat, node_id) do
      nil ->
        {:error, :not_found}

      node ->
        node
        |> slug_path(nodes_flat)
        |> Enum.join("/")
    end
  end

  def has_children?(node), do: node.children != []

  def parent_options(nodes, node_id) do
    node = nodes |> Enum.find(&(&1.id == node_id))
    slug = node.slug
    parent_id = node.parent_id

    forbidden_ids =
      [node_id, parent_id] ++
        descendant_ids(node_id, nodes) ++
        parent_ids_with_child_slug(slug, nodes)

    [get_node_by_id(nodes, nil) | nodes]
    |> Enum.reject(&(&1.id in forbidden_ids))
  end

  defp descendant_ids(root_id, nodes) do
    children =
      nodes
      |> Enum.filter(&(&1.parent_id == root_id))
      |> Enum.map(& &1.id)

    children ++ Enum.flat_map(children, &descendant_ids(&1, nodes))
  end

  defp parent_ids_with_child_slug(slug, nodes) do
    nodes
    |> Enum.filter(&(&1.slug == slug))
    |> Enum.map(& &1.parent_id)
  end

  defp slug_path(%{parent_id: nil, slug: slug}, _nodes_flat), do: [slug]

  defp slug_path(node, nodes_flat) do
    parent = get_node_by_id(nodes_flat, node.parent_id)

    case parent do
      nil -> [node.slug]
      parent -> slug_path(parent, nodes_flat) ++ [node.slug]
    end
  end
end
