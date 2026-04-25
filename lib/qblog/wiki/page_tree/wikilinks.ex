defmodule Qblog.Wiki.PageTree.Wikilinks do
  alias Qblog.Wiki.PageTree
  alias Qblog.Wiki.PageTree.Node
  alias Qblog.Wiki.PageTree.TreeQueries
  alias Utils.Slugify

  @visible_wikilink_regex ~r/\[\[([^\]\n]+)\]\]/
  @node_wikilink_regex ~r/\[\[node:(\d+)\]\]/

  @spec replace_visible(String.t(), (String.t(), String.t() -> String.t())) :: String.t()
  def replace_visible(markdown, replacement)
      when is_binary(markdown) and is_function(replacement, 2) do
    Regex.replace(@visible_wikilink_regex, markdown, replacement)
  end

  @spec title_paths_to_nodes(String.t(), %{String.t() => integer()}) :: String.t()
  def title_paths_to_nodes(markdown, title_path_to_node_id_map)
      when is_binary(markdown) and is_map(title_path_to_node_id_map) do
    replace_visible(markdown, fn wikilink, path ->
      path = String.trim(path)

      case Map.get(title_path_to_node_id_map, path) do
        nil -> wikilink
        node_id -> "[[node:#{node_id}]]"
      end
    end)
  end

  @spec nodes_to_title_paths(String.t(), PageTree.t()) :: String.t()
  def nodes_to_title_paths(markdown, %{nodes: nodes}) when is_binary(markdown) do
    Regex.replace(@node_wikilink_regex, markdown, fn wikilink, node_id ->
      node_id = String.to_integer(node_id)

      case TreeQueries.get_node(nodes, node_id) do
        nil -> wikilink
        node -> "[[#{TreeQueries.get_node_title_path(nodes, node.id)}]]"
      end
    end)
  end

  @spec title_paths_to_node_id_map([Node.t()]) :: %{String.t() => integer()}
  def title_paths_to_node_id_map(nodes) when is_list(nodes) do
    nodes
    |> unique_page_nodes_by_title_path()
    |> Map.new(fn node ->
      {TreeQueries.get_node_title_path(nodes, node.id), node.id}
    end)
  end

  @spec title_paths_to_slug_path_map([Node.t()]) :: %{String.t() => String.t()}
  def title_paths_to_slug_path_map(nodes) when is_list(nodes) do
    nodes
    |> unique_page_nodes_by_title_path()
    |> Map.new(fn node ->
      {TreeQueries.get_node_title_path(nodes, node.id), TreeQueries.get_node_path(nodes, node.id)}
    end)
  end

  @spec slug_path_from_title_path(String.t()) :: String.t() | nil
  def slug_path_from_title_path(title_path) when is_binary(title_path) do
    title_path
    |> String.split("/", trim: true)
    |> Enum.map(&(&1 |> String.trim() |> Slugify.generate()))
    |> then(fn segments ->
      if segments == [] or Enum.any?(segments, &(&1 == "")) do
        nil
      else
        Enum.join(segments, "/")
      end
    end)
  end

  defp unique_page_nodes_by_title_path(nodes) do
    nodes
    |> Enum.filter(&(not is_nil(&1.page_id)))
    |> Enum.group_by(&TreeQueries.get_node_title_path(nodes, &1.id))
    |> Enum.flat_map(fn
      {"", _nodes} -> []
      {_title_path, [node]} -> [node]
      {_title_path, _nodes} -> []
    end)
  end
end
