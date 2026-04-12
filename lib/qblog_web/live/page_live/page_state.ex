defmodule QblogWeb.PageLive.PageState do
  @moduledoc false

  import Phoenix.Component, only: [assign: 2]

  alias Qblog.Wiki
  alias QblogWeb.PageLive.BlockEdit

  def load_page_and_node_by_path(scope, path) do
    path
    |> Wiki.ensure_node_and_page_at_path(
      scope: scope,
      load: [:author, block_placements: :block]
    )
  end

  def find_block(page, block_id) do
    page
    |> find_placement_by_block_id(block_id)
    |> then(& &1.block)
  end

  def find_placement(page, placement_id) do
    page.block_placements
    |> Enum.find(&(&1.id == placement_id))
  end

  def reload(socket) do
    scope = socket.assigns.current_scope
    {node, page} = scope |> load_page_and_node_by_path(socket.assigns.path)

    socket
    |> sync_block_subscriptions(page)
    |> assign(node: node, page: page)
    |> clear_invalid_edit_state(page)
  end

  def sync_block_subscriptions(socket, page) do
    if Phoenix.LiveView.connected?(socket) do
      current_block_ids = page.block_placements |> Enum.map(& &1.block.id) |> MapSet.new()
      subscribed_block_ids = socket.assigns[:subscribed_block_ids] || MapSet.new()
      block_ids_to_subscribe = current_block_ids |> MapSet.difference(subscribed_block_ids)
      block_ids_to_unsubscribe = subscribed_block_ids |> MapSet.difference(current_block_ids)

      Enum.each(block_ids_to_subscribe, &QblogWeb.Endpoint.subscribe("block:#{&1}"))
      Enum.each(block_ids_to_unsubscribe, &QblogWeb.Endpoint.unsubscribe("block:#{&1}"))

      socket |> assign(subscribed_block_ids: current_block_ids)
    else
      socket
    end
  end

  defp clear_invalid_edit_state(socket, page) do
    editing_block_id = socket.assigns.editing_block_id
    editing_block? = page.block_placements |> Enum.any?(&(&1.block.id == editing_block_id))

    if editing_block? do
      socket
    else
      socket |> BlockEdit.clear()
    end
  end

  defp find_placement_by_block_id(page, block_id) do
    page.block_placements
    |> Enum.find(&(&1.block.id == block_id))
  end
end
