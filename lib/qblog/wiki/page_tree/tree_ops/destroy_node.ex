defmodule Qblog.Wiki.PageTree.TreeOps.DestroyNode do
  def call(nodes, node_id) when is_list(nodes) do
    cond do
      not has_node?(nodes, node_id) ->
        {:error, "node not found"}

      has_children?(nodes, node_id) ->
        {:error, "cannot remove a node that has children"}

      true ->
        {:ok, Enum.reject(nodes, &(&1.id == node_id))}
    end
  end

  defp has_node?(nodes, node_id) do
    Enum.any?(nodes, &(&1.id == node_id))
  end

  defp has_children?(nodes, node_id) do
    Enum.any?(nodes, &(&1.parent_id == node_id))
  end
end
