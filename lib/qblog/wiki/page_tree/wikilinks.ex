defmodule Qblog.Wiki.PageTree.Wikilinks do
  alias Qblog.Wiki.PageTree.TreeQueries

  @visible_wikilink_regex ~r/\[\[([^\]\n]+)\]\]/
  @node_wikilink_regex ~r/\[\[node:(\d+)\]\]/

  def replace_visible(markdown, replacement)
      when is_binary(markdown) and is_function(replacement, 2) do
    Regex.replace(@visible_wikilink_regex, markdown, replacement)
  end

  def paths_to_nodes(markdown, path_to_node_map)
      when is_binary(markdown) and is_map(path_to_node_map) do
    replace_visible(markdown, fn wikilink, path ->
      path = String.trim(path)

      case Map.get(path_to_node_map, path) do
        nil -> wikilink
        node_id -> "[[node:#{node_id}]]"
      end
    end)
  end

  def nodes_to_paths(markdown, %{nodes: nodes}) when is_binary(markdown) do
    Regex.replace(@node_wikilink_regex, markdown, fn wikilink, node_id ->
      node_id = String.to_integer(node_id)

      case TreeQueries.get_node(nodes, node_id) do
        nil -> wikilink
        node -> "[[#{TreeQueries.get_node_path(nodes, node.id)}]]"
      end
    end)
  end

  def nodes_to_id_map(nodes) when is_list(nodes) do
    nodes
    |> Enum.filter(&(not is_nil(&1.page_id)))
    |> Enum.map(fn node ->
      {TreeQueries.get_node_path(nodes, node.id), node.id}
    end)
    |> Enum.reject(fn {path, _node_id} -> path == "" end)
    |> Map.new()
  end
end
