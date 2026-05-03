defmodule Wik.Wiki.PageTree.TreeOps.MoveNode do
  def call(nodes, node_id, new_parent_id) when is_list(nodes) do
    cond do
      not has_node?(nodes, node_id) ->
        {:error, "node not found"}

      not is_nil(new_parent_id) and not has_node?(nodes, new_parent_id) ->
        {:error, "new parent not found"}

      node_id == new_parent_id ->
        {:error, "cannot move a node under itself"}

      descendant?(nodes, node_id, new_parent_id) ->
        {:error, "cannot move a node under its descendant"}

      true ->
        {:ok, update_parent(nodes, node_id, new_parent_id)}
    end
  end

  defp has_node?(nodes, id) do
    Enum.any?(nodes, &(&1.id == id))
  end

  defp update_parent(nodes, node_id, new_parent_id) do
    Enum.map(nodes, fn
      %{id: ^node_id} = node -> %{node | parent_id: new_parent_id}
      node -> node
    end)
  end

  # --- cycle check ---

  defp descendant?(_nodes, _node_id, nil), do: false

  defp descendant?(nodes, node_id, candidate_parent_id) do
    candidate_parent_id in descendants(nodes, node_id)
  end

  defp descendants(nodes, root_id) do
    children =
      nodes
      |> Enum.filter(&(&1.parent_id == root_id))
      |> Enum.map(& &1.id)

    children ++ Enum.flat_map(children, &descendants(nodes, &1))
  end
end
