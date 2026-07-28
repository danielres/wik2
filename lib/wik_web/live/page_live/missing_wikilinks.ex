defmodule WikWeb.PageLive.MissingWikilinks do
  alias Wik.Blocks
  alias Wik.Blocks.Block
  alias Wik.Blocks.Types.Markdown, as: MarkdownBlock
  alias Wik.Wiki.PageTree.TreeQueries
  alias Wik.Wiki.PageTree.Wikilinks

  def canonicalize_source(socket, params) when is_map(params) do
    with {:ok, source} <- source_from_params(params),
         false <- source_locked?(socket, source.block_id),
         %{} = scope <- socket.assigns.current_scope,
         %{id: node_id} <- socket.assigns.node,
         {:ok, target_title_path} <- target_title_path(socket, source),
         {:ok, %{type: :markdown, data: %{"text" => text}} = block} <-
           Block.get_by_id(source.block_id, scope: scope),
         true <- MarkdownBlock.source_text_hash(text) == source.text_hash,
         updated_text when updated_text != text <-
           Wikilinks.replace_title_path_with_node(text, target_title_path, node_id),
         {:ok, _block} <- Blocks.update_block(block, %{"text" => updated_text}, scope: scope) do
      socket
    else
      {:error, :missing_source_params} ->
        socket

      true ->
        socket

      false ->
        socket

      {:ok, _block} ->
        socket

      updated_text when is_binary(updated_text) ->
        socket

      {:error, error} ->
        log_error(socket, error)
        socket

      _other ->
        socket
    end
  end

  defp source_from_params(%{
         "wikilink_source_block_id" => block_id,
         "wikilink_source_text_hash" => text_hash,
         "wikilink_source_title_path" => title_path
       })
       when is_binary(block_id) and is_binary(text_hash) and is_binary(title_path) do
    {:ok, %{block_id: block_id, text_hash: text_hash, title_path: title_path}}
  end

  defp source_from_params(_params), do: {:error, :missing_source_params}

  defp source_locked?(socket, block_id) do
    socket.assigns
    |> Map.get(:locks, %{})
    |> Map.has_key?(block_id)
  end

  defp target_title_path(%{assigns: %{node: %{id: node_id}, page_tree: %{nodes: nodes}}}, %{
         title_path: title_path
       }) do
    target_title_path =
      nodes
      |> TreeQueries.get_node_title_path(node_id)
      |> String.trim()

    if target_title_path == String.trim(title_path) do
      {:ok, target_title_path}
    else
      {:error, :target_mismatch}
    end
  end

  defp target_title_path(_socket, _source), do: {:error, :target_mismatch}

  defp log_error(%{assigns: %{current_scope: scope}}, error),
    do: Utils.Log.scoped_error(scope, error, "missing wikilink canonicalization failed")

  defp log_error(_socket, _error), do: :ok
end
