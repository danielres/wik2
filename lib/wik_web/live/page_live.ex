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
  alias WikWeb.PageLive.EditMode
  alias WikWeb.PageLive.Locks
  alias WikWeb.PageLive.LibraryEntries
  alias WikWeb.PageLive.MissingWikilinks
  alias WikWeb.PageLive.PageAuthor
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
      |> LibraryEntries.assign_defaults()

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
      |> LibraryEntries.sync_page()
      |> PageTopics.sync_subscription()
      |> PageTopics.assign_topics()
      # |> PageTopics.open_form()
      |> PageAuthor.assign_membership()
      |> Presence.track_in_liveview(url)
      |> Locks.assign_locks()
      |> MissingWikilinks.canonicalize_source(params)

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
    do: {:noreply, socket |> EditMode.toggle() |> LibraryEntries.sync_edit_mode()}

  # page_topic -----------------------------------------------------------------

  @impl true
  def handle_event("page_topic:add_start", _params, socket),
    do: {:noreply, PageTopics.open_form(socket)}

  @impl true
  def handle_event("page_topic:add_cancel", _params, socket),
    do: {:noreply, PageTopics.close_form(socket)}

  @impl true
  def handle_event("page_topic:edit_cancel", _params, socket),
    do: {:noreply, PageTopics.edit_cancel(socket)}

  @impl true
  def handle_event("page_topic:edit_remove", _params, socket),
    do: {:noreply, PageTopics.edit_remove(socket)}

  @impl true
  def handle_event("page_topic:edit_start", %{"tagging_id" => tagging_id}, socket),
    do: {:noreply, PageTopics.edit_start(socket, tagging_id)}

  @impl true
  def handle_event("page_topic:edit_submit", %{"page_topic_edit" => params}, socket),
    do: {:noreply, PageTopics.edit_submit(socket, params)}

  @impl true
  def handle_event("page_topic:edit_validate", %{"page_topic_edit" => params}, socket),
    do: {:noreply, PageTopics.edit_validate(socket, params)}

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
  def handle_event("block:edit_start", %{"block_id" => block_id}, socket) do
    socket =
      socket
      |> LibraryEntries.cancel_edit()
      |> BlockActions.start_edit(block_id)
      |> LibraryEntries.refresh_placements()

    {:noreply, socket}
  end

  @impl true
  def handle_event("block:edit_cancel", %{"block_id" => block_id}, socket) do
    socket =
      if socket.assigns.editing_block_id == block_id do
        socket |> BlockEdit.clear() |> LibraryEntries.refresh_placements()
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "block:edit_submit",
        %{"block" => params, "block_id" => block_id},
        socket
      ),
      do:
        {:noreply,
         socket |> BlockActions.save_edit(block_id, params) |> LibraryEntries.refresh_placements()}

  @impl true
  def handle_event("block:add", %{"type" => type_param}, socket),
    do: {:noreply, socket |> BlockActions.add(type_param)}

  @impl true
  def handle_event("block:add_start", %{"position" => position}, socket)
      when position in ["top", "bottom"],
      do: {:noreply, LibraryEntries.start_add(socket, position)}

  @impl true
  def handle_event("block:add_cancel", _params, socket),
    do: {:noreply, socket |> assign(add_block_modal_open?: false)}

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

  # library entries ------------------------------------------------------------

  @impl true
  def handle_event("library_entry:choose_type", %{"type_id" => type_id}, socket),
    do: {:noreply, LibraryEntries.choose_type(socket, type_id)}

  @impl true
  def handle_event("library_entry:back_to_block_menu", _params, socket),
    do: {:noreply, LibraryEntries.back_to_block_menu(socket)}

  @impl true
  def handle_event("library_entry:close_modal", _params, socket),
    do: {:noreply, LibraryEntries.close_modal(socket)}

  @impl true
  def handle_event("library_entry:search", %{"library_search" => %{"query" => query}}, socket),
    do: {:noreply, LibraryEntries.search(socket, query)}

  @impl true
  def handle_event("library_entry:start_create", _params, socket),
    do: {:noreply, LibraryEntries.start_create(socket)}

  @impl true
  def handle_event("library_entry:back_to_chooser", _params, socket),
    do: {:noreply, LibraryEntries.back_to_chooser(socket)}

  @impl true
  def handle_event("library_entry:change_create", %{"entry" => params}, socket),
    do: {:noreply, LibraryEntries.change_create(socket, params)}

  @impl true
  def handle_event("library_entry:create", %{"entry" => params}, socket),
    do: {:noreply, LibraryEntries.create(socket, params)}

  @impl true
  def handle_event("library_entry:insert", %{"entry_id" => entry_id}, socket),
    do: {:noreply, LibraryEntries.insert(socket, entry_id)}

  @impl true
  def handle_event("library_entry:show", %{"entry_id" => entry_id}, socket),
    do: {:noreply, LibraryEntries.show(socket, entry_id)}

  @impl true
  def handle_event("library_entry:playlist_play", %{"video_id" => video_id}, socket),
    do: {:noreply, LibraryEntries.play_video(socket, video_id)}

  @impl true
  def handle_event("library_entry:start_edit", %{"placement_id" => placement_id}, socket),
    do: {:noreply, LibraryEntries.start_edit(socket, placement_id)}

  @impl true
  def handle_event("library_entry:change_edit", %{"entry" => params}, socket),
    do: {:noreply, LibraryEntries.change_edit(socket, params)}

  @impl true
  def handle_event("library_entry:save_edit", %{"entry" => params}, socket),
    do: {:noreply, LibraryEntries.save_edit(socket, params)}

  @impl true
  def handle_event("library_entry:cancel_edit", _params, socket),
    do: {:noreply, LibraryEntries.cancel_edit(socket)}

  @impl true
  def handle_event("library_entry:remove", %{"placement_id" => placement_id}, socket),
    do: {:noreply, LibraryEntries.remove(socket, placement_id)}

  @impl true
  def handle_event(
        "library_entry:move",
        %{"direction" => direction, "placement_id" => placement_id},
        socket
      ),
      do: {:noreply, LibraryEntries.move(socket, placement_id, direction)}

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
end
