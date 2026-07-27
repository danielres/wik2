defmodule WikWeb.PageLive do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers

  alias WikWeb.Components
  alias WikWeb.Components.UI
  alias WikWeb.PageLive
  alias WikWeb.PageLive.BlockActions
  alias WikWeb.PageLive.BlockEdit
  alias WikWeb.PageLive.BlockHistory
  alias WikWeb.PageLive.BlockInfo
  alias WikWeb.PageLive.Locks
  alias WikWeb.PageLive.PageState
  alias WikWeb.PageLive.PageTopics
  alias WikWeb.Presence
  alias WikWeb.Presence.Handlers

  on_mount {WikWeb.LiveUserAuth, :live_scope_required}
  on_mount {WikWeb.LiveUserAuth, :subscribe_presence}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        add_block_modal_open?: false,
        add_block_position: "bottom",
        author_membership: nil,
        block_history_placement: nil,
        block_info_author_membership: nil,
        block_info_placement: nil,
        can_manage_page?: false,
        editing?: false,
        editing_block_id: nil,
        form_edit_block: nil,
        linked_copy_error: nil,
        linked_copy_form: nil,
        node: nil,
        not_found_path: nil,
        page: nil,
        page_tree: nil,
        path: nil
      )
      |> PageTopics.assign_defaults()
      |> Locks.assign_locks()

    {:ok, socket}
  end

  # ============================================================================
  # PRESENCE
  # ============================================================================

  def handle_presence_change(socket) do
    socket
    |> Handlers.handle_presence_change()
    |> Locks.assign_locks()
  end

  @impl true
  def handle_params(params, url, socket) do
    path = params["path"] |> Enum.join("/")
    title_path = params["title_path"]

    socket =
      socket
      |> PageState.load_path(path, title_path: title_path)
      |> PageTopics.sync_subscription()
      |> PageTopics.assign_topics()
      |> load_page_author_membership()
      |> Presence.track_in_liveview(url)
      |> Locks.assign_locks()

    {:noreply, socket}
  end

  # ============================================================================
  # SUBSCRIPTIONS
  # ============================================================================

  @impl true
  def handle_info(%{topic: "block:" <> _block_id}, socket),
    do: {:noreply, socket |> PageState.reload()}

  @impl true
  def handle_info(%{topic: "block_placement:page:" <> _page_id}, socket),
    do: {:noreply, socket |> PageState.reload() |> PageTopics.assign_topics()}

  @impl true
  def handle_info(%{topic: topic}, socket),
    do: {:noreply, PageTopics.refresh_if_watched(socket, topic)}

  # ============================================================================
  # EVENTS
  # ============================================================================

  # edit -----------------------------------------------------------------------

  @impl true
  def handle_event("edit_mode:toggle", _params, socket),
    do: {:noreply, toggle_edit_mode(socket)}

  # page_topic -----------------------------------------------------------------

  @impl true
  def handle_event("page_topic:add_start", _params, socket),
    do: {:noreply, PageTopics.open_form(socket)}

  @impl true
  def handle_event("page_topic:add_cancel", _params, socket),
    do: {:noreply, PageTopics.close_form(socket)}

  @impl true
  def handle_event("page_topic:validate", %{"page_topic" => params}, socket),
    do: {:noreply, PageTopics.validate(socket, params)}

  @impl true
  def handle_event("page_topic:submit", %{"page_topic" => params}, socket),
    do: {:noreply, PageTopics.submit(socket, params)}

  @impl true
  def handle_event("page_topic:remove", %{"tag_id" => tag_id}, socket),
    do: {:noreply, PageTopics.remove(socket, tag_id)}

  # block ----------------------------------------------------------------------

  @impl true
  def handle_event("block:edit_start", %{"block_id" => block_id}, socket),
    do: {:noreply, BlockActions.start_edit(socket, block_id)}

  @impl true
  def handle_event("block:edit_cancel", %{"block_id" => block_id}, socket) do
    if socket.assigns.editing_block_id == block_id do
      {:noreply, socket |> BlockEdit.clear()}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "block:edit_submit",
        %{"block" => params, "block_id" => block_id},
        socket
      ),
      do: {:noreply, socket |> BlockActions.save_edit(block_id, params)}

  @impl true
  def handle_event("block:add", %{"type" => type_param}, socket),
    do: {:noreply, socket |> BlockActions.add(type_param)}

  @impl true
  def handle_event("block:add_start", _params, socket),
    do: {:noreply, socket |> assign(add_block_modal_open?: true)}

  @impl true
  def handle_event("block:add_cancel", _params, socket),
    do: {:noreply, socket |> assign(add_block_modal_open?: false)}

  @impl true
  def handle_event("block:add_position_select", %{"position" => "top"}, socket),
    do: {:noreply, socket |> assign(add_block_position: "top")}

  @impl true
  def handle_event("block:add_position_select", %{"position" => "bottom"}, socket),
    do: {:noreply, socket |> assign(add_block_position: "bottom")}

  @impl true
  def handle_event("block:move_down", %{"placement_id" => placement_id}, socket),
    do: {:noreply, socket |> BlockActions.move_down(placement_id)}

  @impl true
  def handle_event("block:move_up", %{"placement_id" => placement_id}, socket),
    do: {:noreply, socket |> BlockActions.move_up(placement_id)}

  @impl true
  def handle_event("block:destroy", %{"placement_id" => placement_id}, socket),
    do: {:noreply, socket |> BlockActions.destroy(placement_id)}

  @impl true
  def handle_event("block:toggle_aside", %{"placement_id" => placement_id}, socket),
    do: {:noreply, socket |> BlockActions.toggle_aside(placement_id)}

  # linked_copy ----------------------------------------------------------------

  @impl true
  def handle_event("linked_copy:cancel", _params, socket),
    do: {:noreply, socket |> assign(linked_copy_form: nil, linked_copy_error: nil)}

  @impl true
  def handle_event(
        "linked_copy:submit",
        %{"linked_copy" => %{"block_id" => block_id, "position" => position}},
        socket
      ) do
    {:noreply, socket |> BlockActions.add_linked_copy(block_id, position)}
  end

  # block_info -----------------------------------------------------------------

  @impl true
  def handle_event("block_info:show", %{"placement_id" => placement_id}, socket),
    do: {:noreply, BlockInfo.show(socket, placement_id)}

  @impl true
  def handle_event("block_info:hide", _params, socket),
    do: {:noreply, BlockInfo.hide(socket)}

  # block_history --------------------------------------------------------------

  @impl true
  def handle_event("block_history:show", %{"placement_id" => placement_id}, socket),
    do: {:noreply, BlockHistory.show(socket, placement_id)}

  @impl true
  def handle_event("block_history:hide", _params, socket),
    do: {:noreply, BlockHistory.hide(socket)}

  # ============================================================================
  # PRIVATE
  # ============================================================================

  defp has_area?(page, area), do: Enum.any?(page.block_placements, &(&1.area == area))

  defp toggle_edit_mode(socket) do
    socket = socket |> assign(editing?: !socket.assigns.editing?)

    if socket.assigns.editing?,
      do: socket,
      else: socket |> BlockEdit.clear() |> PageTopics.close_form()
  end

  defp load_page_author_membership(
         %{assigns: %{current_scope: scope, page: %{author: author}}} = socket
       ) do
    case Wik.Accounts.get_membership(scope.tenant, author) do
      {:ok, membership} ->
        assign(socket, :author_membership, membership)

      {:error, error} ->
        Utils.Log.scoped_error(scope, error, "load_page_author_membership failed")
        assign(socket, :author_membership, nil)
    end
  end

  defp load_page_author_membership(socket), do: assign(socket, :author_membership, nil)
end
