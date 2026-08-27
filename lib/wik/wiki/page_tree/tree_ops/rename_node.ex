defmodule Wik.Wiki.PageTree.TreeOps.RenameNode do
  def call(nodes, node_id, slug, title) when is_list(nodes) do
    if Enum.any?(nodes, &(&1.id == node_id)) do
      renamed_nodes =
        Enum.map(nodes, fn
          %{id: ^node_id} = node -> %{node | slug: slug, title: title}
          node -> node
        end)

      {:ok, renamed_nodes}
    else
      {:error, "node not found"}
    end
  end
end
