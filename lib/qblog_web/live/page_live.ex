# TODO: break this up, too much going on in this file.

defmodule QblogWeb.PageLive do
  use QblogWeb, :live_view
  use QblogWeb.Presence.Handlers

  alias Qblog.Wiki
  alias QblogWeb.Endpoint
  alias QblogWeb.PageLive.BlockActions
  alias QblogWeb.PageLive.BlockEdit
  alias QblogWeb.PageLive.Locks
  alias QblogWeb.PageLive.PageState
  alias QblogWeb.Presence
  alias QblogWeb.Presence.Handlers

  on_mount {QblogWeb.LiveUserAuth, :live_scope_required}
  on_mount {QblogWeb.LiveUserAuth, :subscribe_presence}

  @impl true
  def mount(params, _session, socket) do
    path = params["path"] |> Enum.join("/")
    scope = socket.assigns.current_scope
    {node, page} = scope |> PageState.load_page_and_node_by_path(path)

    if page != nil or Ash.can?({Wiki.Page, :create}, scope) do
      socket =
        socket
        |> assign(node: node, page: page, path: path)
        |> assign(editing_block_id: nil, form_edit_block: nil, editing?: false)
        |> PageState.sync_block_subscriptions(page)
        |> Locks.assign_locks()

      if connected?(socket), do: Endpoint.subscribe("block_placement:page:#{page.id}")
      {:ok, socket}
    else
      socket = socket |> assign(not_found_path: path)
      {:ok, socket}
    end
  end

  # Presence ===================================================================

  def handle_presence_change(socket) do
    socket
    |> Handlers.handle_presence_change()
    |> Locks.assign_locks()
  end

  @impl true
  def handle_params(_params, url, socket) do
    {:noreply, socket |> Presence.track_in_liveview(url)}
  end

  # subscriptions ==============================================================

  @impl true
  def handle_info(%{topic: "block:" <> _block_id}, socket) do
    {:noreply, socket |> PageState.reload()}
  end

  @impl true
  def handle_info(%{topic: "block_placement:page:" <> _page_id}, socket) do
    {:noreply, socket |> PageState.reload()}
  end

  # Edit =======================================================================

  @impl true
  def handle_event("toggle_edit_mode", _params, socket) do
    # TODO: add Ash.can? check to only allow users with edit permissions to toggle edit mode
    socket = socket |> assign(editing?: !socket.assigns.editing?)
    socket = if socket.assigns.editing?, do: socket, else: socket |> BlockEdit.clear()
    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_block_start", %{"block_id" => block_id}, socket) do
    {:noreply, socket |> BlockActions.start_edit(block_id)}
  end

  @impl true
  def handle_event("edit_block_cancel", %{"block_id" => block_id}, socket) do
    if socket.assigns.editing_block_id == block_id do
      {:noreply, socket |> BlockEdit.clear()}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "edit_block_submit",
        %{"block" => params, "block_id" => block_id},
        socket
      ) do
    {:noreply, socket |> BlockActions.save_edit(block_id, params)}
  end


  @impl true
  def handle_event("add_block", %{"type" => type_param}, socket) do
    {:noreply, socket |> BlockActions.add(type_param)}
  end


  @impl true
  def handle_event("move_block_down", %{"placement_id" => placement_id}, socket) do
    {:noreply, socket |> BlockActions.move_down(placement_id)}
  end

  @impl true
  def handle_event("move_block_up", %{"placement_id" => placement_id}, socket) do
    {:noreply, socket |> BlockActions.move_up(placement_id)}
  end

  @impl true
  def handle_event("destroy_block", %{"placement_id" => placement_id}, socket) do
    {:noreply, socket |> BlockActions.destroy(placement_id)}
  end

  @impl true
  def handle_event("toggle_block_width", %{"placement_id" => placement_id}, socket) do
    {:noreply, socket |> BlockActions.toggle_width(placement_id)}
  end

end
