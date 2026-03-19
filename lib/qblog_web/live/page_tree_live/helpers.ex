defmodule QblogWeb.PageTreeLive.Helpers do
  def has_children?(node), do: node.children != []

  def parent_options(nodes, node_id) do
    forbidden_ids = [node_id | descendants(nodes, node_id)]

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
