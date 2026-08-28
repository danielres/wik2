defmodule WikWeb.PageLive.PageState do
  @moduledoc false

  import Phoenix.Component, only: [assign: 2]

  alias Wik.Wiki
  alias Wik.Wiki.Page
  alias Wik.Wiki.PageTree
  alias Wik.Wiki.PageTree.Node
  alias WikWeb.PageLive.BlockEdit

  @page_load [:author, block_placements: [block: :author]]

  def load_by_path(scope, path) do
    page_tree = scope |> Wiki.load_page_tree()
    node_result = PageTree.get_node_by_path(page_tree.nodes, path)

    {node, page} =
      case node_result do
        {:ok, node} -> {node, scope |> Node.load_page(node, load: @page_load)}
        {:error, _error} -> {nil, nil}
      end

    %{node: node, page: page, page_tree: page_tree}
  end

  def load_path(socket, path, opts \\ []) do
    scope = socket.assigns.current_scope
    %{node: node, page: page, page_tree: page_tree} = scope |> ensure_by_path(path, opts)
    can_manage_page? = page != nil and Page.can_manage_page?(scope.actor, page, scope: scope)

    socket
    |> sync_page_placement_subscription(page)
    |> sync_block_subscriptions(page)
    |> assign(
      add_block_modal_open?: false,
      block_info_placement: nil,
      can_manage_page?: can_manage_page?,
      editing_block_id: nil,
      form_edit_block: nil,
      linked_copy_error: nil,
      linked_copy_form: nil,
      node: node,
      not_found_path: if(page == nil, do: path, else: nil),
      page: page,
      page_tree: page_tree,
      path: path
    )
  end

  def ensure_by_path(scope, path, opts \\ []) do
    %{node: node, page: page, page_tree: page_tree} = scope |> load_by_path(path)
    title_path = Keyword.get(opts, :title_path)

    if page == nil do
      case path
           |> Wiki.ensure_page_and_node_at_path(
             scope: scope,
             load: @page_load,
             title_path: title_path
           ) do
        {:ok, node, page} ->
          %{node: node, page: page, page_tree: Wiki.load_page_tree(scope)}

        {:error, %Ash.Error.Forbidden{}} ->
          %{node: node, page: page, page_tree: page_tree}

        {:error, error} ->
          Utils.Log.scoped_error(scope, error, "PageState.ensure_by_path failed")
          %{node: node, page: page, page_tree: page_tree}
      end
    else
      %{node: node, page: page, page_tree: page_tree}
    end
  end

  def get_block(nil, _block_id), do: {:error, :not_found}

  def get_block(page, block_id) do
    case find_placement_by_block_id(page, block_id) do
      nil -> {:error, :not_found}
      placement -> {:ok, placement.block}
    end
  end

  def get_placement(nil, _placement_id), do: {:error, :not_found}

  def get_placement(page, placement_id) do
    case find_placement(page, placement_id) do
      nil -> {:error, :not_found}
      placement -> {:ok, placement}
    end
  end

  defp find_placement(page, placement_id) do
    page.block_placements
    |> Enum.find(&(&1.id == placement_id))
  end

  def reload(socket) do
    scope = socket.assigns.current_scope
    %{node: node, page: page, page_tree: page_tree} = scope |> load_by_path(socket.assigns.path)
    can_manage_page? = page != nil and Page.can_manage_page?(scope.actor, page, scope: scope)

    socket
    |> sync_page_placement_subscription(page)
    |> sync_block_subscriptions(page)
    |> assign(
      can_manage_page?: can_manage_page?,
      node: node,
      page_tree: page_tree,
      page: page,
      not_found_path: if(page == nil, do: socket.assigns.path, else: nil)
    )
    |> clear_invalid_edit_state(page)
  end

  def sync_block_subscriptions(socket, page) do
    if Phoenix.LiveView.connected?(socket) do
      current_block_ids =
        page
        |> case do
          nil -> MapSet.new()
          page -> page.block_placements |> Enum.map(& &1.block.id) |> MapSet.new()
        end

      subscribed_block_ids = socket.assigns[:subscribed_block_ids] || MapSet.new()
      block_ids_to_subscribe = current_block_ids |> MapSet.difference(subscribed_block_ids)
      block_ids_to_unsubscribe = subscribed_block_ids |> MapSet.difference(current_block_ids)

      Enum.each(block_ids_to_subscribe, &WikWeb.Endpoint.subscribe("block:#{&1}"))
      Enum.each(block_ids_to_unsubscribe, &WikWeb.Endpoint.unsubscribe("block:#{&1}"))

      socket |> assign(subscribed_block_ids: current_block_ids)
    else
      socket
    end
  end

  defp sync_page_placement_subscription(socket, page) do
    if Phoenix.LiveView.connected?(socket) do
      current_page_id = if page == nil, do: nil, else: page.id
      subscribed_page_id = socket.assigns[:subscribed_block_placement_page_id]

      if subscribed_page_id != nil and subscribed_page_id != current_page_id do
        WikWeb.Endpoint.unsubscribe("block_placement:page:#{subscribed_page_id}")
      end

      if current_page_id != nil and current_page_id != subscribed_page_id do
        WikWeb.Endpoint.subscribe("block_placement:page:#{current_page_id}")
      end

      socket |> assign(subscribed_block_placement_page_id: current_page_id)
    else
      socket
    end
  end

  defp clear_invalid_edit_state(socket, page) do
    editing_block_id = socket.assigns.editing_block_id

    editing_block? =
      page != nil and page.block_placements |> Enum.any?(&(&1.block.id == editing_block_id))

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
