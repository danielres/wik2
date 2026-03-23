defmodule QblogWeb.PageTreeLive.Helpers do
  def get_node_by_id(_nodes_flat, nil) do
    %{slug: "Top", id: nil}
  end

  def get_node_by_id(nodes_flat, id) do
    nodes_flat |> Enum.find(fn node -> node.id == id end)
  end

  def has_children?(node), do: node.children != []

  def parent_options(nodes, node_id) do
    node = nodes |> Enum.find(&(&1.id == node_id))
    parent_id = node.parent_id

    forbidden_ids = [node_id, parent_id] ++ descendants(nodes, node_id)

    Enum.reject(nodes, &(&1.id in forbidden_ids))
  end

  defp descendants(nodes, root_id) do
    children =
      nodes
      |> Enum.filter(&(&1.parent_id == root_id))
      |> Enum.map(& &1.id)

    children ++ Enum.flat_map(children, &descendants(nodes, &1))
  end
end
