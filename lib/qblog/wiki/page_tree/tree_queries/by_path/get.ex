defmodule Qblog.Wiki.PageTree.TreeQueries.ByPath.Get do
  alias Qblog.Wiki.PageTree.TreeQueries

  def call(nodes, path) when is_binary(path) do
    nodes
    |> call(String.split(path, "/", trim: true))
  end

  def call(nodes, path) when is_list(path) do
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
        {:ok, TreeQueries.get_node(nodes, node_id)}
    end
  end

  defp find_node_by_slug_and_parent_id(nodes, slug, parent_id) do
    Enum.find(nodes, &(&1.slug == slug and &1.parent_id == parent_id))
  end
end
