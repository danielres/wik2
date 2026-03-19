defmodule Qblog.Wiki.PageTree.TreeOps.AddChild do
  def call(nodes, parent_node_id) when is_list(nodes) do
    cond do
      is_nil(parent_node_id) ->
        {:ok, nodes ++ [new_node(nodes, nil)]}

      has_node?(nodes, parent_node_id) ->
        {:ok, nodes ++ [new_node(nodes, parent_node_id)]}

      true ->
        {:error, "parent node not found"}
    end
  end

  defp has_node?(nodes, id) do
    Enum.any?(nodes, &(&1.id == id))
  end

  defp new_node(nodes, parent_id) do
    %{
      id: next_id(nodes),
      page_id: nil,
      parent_id: parent_id
    }
  end

  defp next_id([]), do: 1

  defp next_id(nodes) do
    nodes
    |> Enum.map(& &1.id)
    |> Enum.max()
    |> Kernel.+(1)
  end
end
