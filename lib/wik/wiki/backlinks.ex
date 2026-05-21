defmodule Wik.Wiki.Backlinks do
  alias Ash.Query
  alias Wik.Blocks.BlockPlacement
  alias Wik.Wiki.PageTree
  alias Wik.Wiki.PageTree.TreeQueries

  require Ash.Query

  def list_pages_linking_to_node(
        %{tenant: %{id: space_id}} = scope,
        %{id: target_node_id, page_id: target_page_id},
        %PageTree{nodes: nodes}
      ) do
    BlockPlacement
    |> Query.filter(attachable_type == "page" and space_id == ^space_id)
    |> Ash.read(scope: scope, load: [:block])
    |> case do
      {:ok, placements} ->
        {:ok, placements_to_backlink_pages(placements, nodes, target_node_id, target_page_id)}

      {:error, error} ->
        {:error, error}
    end
  end

  defp placements_to_backlink_pages(placements, nodes, target_node_id, target_page_id) do
    nodes_by_page_id =
      nodes
      |> Enum.filter(&(not is_nil(&1.page_id)))
      |> Map.new(&{&1.page_id, &1})

    target_marker = "[[node:#{target_node_id}]]"

    placements
    |> Enum.filter(&markdown_backlink?(&1, target_marker))
    |> Enum.reject(&(&1.attachable_id == target_page_id))
    |> Enum.map(&Map.get(nodes_by_page_id, &1.attachable_id))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(& &1.page_id)
    |> Enum.sort_by(&TreeQueries.get_node_path(nodes, &1.id))
    |> Enum.map(fn node ->
      %{
        node_id: node.id,
        page_id: node.page_id,
        path: TreeQueries.get_node_path(nodes, node.id),
        title: node.title
      }
    end)
  end

  defp markdown_backlink?(%{block: %{type: :markdown, data: %{"text" => text}}}, target_marker)
       when is_binary(text) do
    String.contains?(text, target_marker)
  end

  defp markdown_backlink?(_placement, _target_marker), do: false
end
