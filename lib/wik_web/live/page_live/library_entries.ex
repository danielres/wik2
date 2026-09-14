defmodule WikWeb.PageLive.LibraryEntries do
  @moduledoc false

  import Phoenix.Component, only: [assign: 2, assign: 3, to_form: 2]
  import Phoenix.LiveView, only: [stream: 4]

  alias WikWeb.LibraryPrototypeLive.EntryPresentation
  alias WikWeb.LibraryPrototypeLive.State
  alias WikWeb.PageLive.BlockEdit
  alias WikWeb.TenantContext

  def assign_defaults(socket) do
    state = State.new()

    socket
    |> assign(
      library_can_manage_types?:
        TenantContext.space_admin?(socket.assigns.current_scope, socket.assigns.tenant_context),
      library_edit_error: nil,
      library_edit_form: nil,
      library_edit_placement_id: nil,
      library_entry_error: nil,
      library_entry_form: nil,
      library_focused_placement_id: nil,
      library_modal_mode: nil,
      library_picker_form: picker_form(),
      library_placements: [],
      library_selected_entry_id: nil,
      library_selected_playlist_video_id: nil,
      library_selected_type_id: nil,
      library_state: state
    )
    |> stream(:library_picker_entries, [], reset: true)
    |> stream(:library_top_placements, [], reset: true)
    |> stream(:library_bottom_placements, [], reset: true)
  end

  def sync_page(socket) do
    socket
    |> close_modal()
    |> clear_edit()
    |> reset_placement_streams()
  end

  def refresh_placements(socket), do: reset_placement_streams(socket)

  def start_add(socket, position) do
    assign(socket, add_block_modal_open?: true, add_block_position: position)
  end

  def choose_type(socket, type_id) do
    case State.find_type_by_id(socket.assigns.library_state, type_id) do
      nil ->
        put_error(socket, "That Library type is no longer available.")

      type ->
        socket
        |> assign(
          add_block_modal_open?: false,
          library_entry_error: nil,
          library_entry_form: nil,
          library_modal_mode: :chooser,
          library_picker_form: picker_form(),
          library_selected_entry_id: nil,
          library_selected_playlist_video_id: nil,
          library_selected_type_id: type.id
        )
        |> assign_picker_entries("")
    end
  end

  def back_to_block_menu(socket) do
    socket
    |> close_modal()
    |> assign(:add_block_modal_open?, true)
  end

  def close_modal(socket) do
    socket
    |> assign(
      library_entry_error: nil,
      library_entry_form: nil,
      library_modal_mode: nil,
      library_picker_form: picker_form(),
      library_selected_entry_id: nil,
      library_selected_playlist_video_id: nil,
      library_selected_type_id: nil
    )
    |> clear_edit()
    |> stream(:library_picker_entries, [], reset: true)
  end

  def search(socket, query) when is_binary(query) do
    socket
    |> assign(:library_picker_form, picker_form(query))
    |> assign_picker_entries(query)
  end

  def start_create(socket) do
    type = selected_type(socket)

    if type && State.can_create_entry?(type, socket.assigns.library_can_manage_types?) do
      socket
      |> assign(
        library_entry_error: nil,
        library_entry_form: entry_form(nil),
        library_modal_mode: :new
      )
    else
      put_error(socket, "You cannot add entries to that Library type.")
    end
  end

  def back_to_chooser(socket) do
    assign(socket,
      library_entry_error: nil,
      library_entry_form: nil,
      library_modal_mode: :chooser
    )
  end

  def change_create(socket, params) do
    assign(socket, :library_entry_form, entry_form(params))
  end

  def create(socket, params) do
    type = selected_type(socket)
    actor_id = socket.assigns.current_scope.actor.id
    admin? = socket.assigns.library_can_manage_types?

    case type && State.create_entry(socket.assigns.library_state, type, actor_id, admin?, params) do
      {:ok, state, entry} ->
        socket
        |> assign(:library_state, state)
        |> place_entry(entry)

      {:error, errors} when is_list(errors) ->
        socket
        |> assign(:library_entry_error, Enum.join(errors, " · "))
        |> assign(:library_entry_form, entry_form(params))

      _error ->
        put_error(socket, "You cannot add entries to that Library type.")
    end
  end

  def insert(socket, entry_id) do
    state = socket.assigns.library_state
    type = selected_type(socket)
    entry = State.find_entry(state, entry_id)

    if type && entry && entry.type_id == type.id do
      place_entry(socket, entry)
    else
      put_error(socket, "That Library entry is no longer available.")
    end
  end

  def show(socket, entry_id) do
    case State.find_entry(socket.assigns.library_state, entry_id) do
      nil ->
        put_error(socket, "That Library entry is no longer available.")

      entry ->
        socket
        |> assign(
          library_modal_mode: :detail,
          library_selected_entry_id: entry.id,
          library_selected_playlist_video_id: nil,
          library_selected_type_id: entry.type_id
        )
    end
  end

  def play_video(socket, video_id) do
    entry = selected_entry(socket)
    type = selected_type(socket)
    playlist = if entry && type, do: EntryPresentation.playlist(type, entry), else: %{items: []}

    if Enum.any?(playlist.items, &(&1.video_id == video_id)) do
      assign(socket, :library_selected_playlist_video_id, video_id)
    else
      socket
    end
  end

  def start_edit(socket, placement_id) do
    with %{} = placement <- find_placement(socket, placement_id),
         %{} = entry <- State.find_entry(socket.assigns.library_state, placement.entry_id),
         true <- manageable?(socket, entry) do
      socket
      |> BlockEdit.clear()
      |> assign(
        library_edit_error: nil,
        library_edit_form: entry_form(entry.values),
        library_edit_placement_id: placement.id,
        library_modal_mode: :edit,
        library_selected_entry_id: entry.id,
        library_selected_playlist_video_id: nil,
        library_selected_type_id: entry.type_id
      )
    else
      _error -> put_error(socket, "You cannot edit that Library entry.")
    end
  end

  def change_edit(socket, params) do
    assign(socket, :library_edit_form, entry_form(params))
  end

  def save_edit(socket, params) do
    with %{} = placement <- find_placement(socket, socket.assigns.library_edit_placement_id),
         %{} = entry <- State.find_entry(socket.assigns.library_state, placement.entry_id),
         %{} = type <- State.find_type_by_id(socket.assigns.library_state, entry.type_id),
         true <- manageable?(socket, entry),
         {:ok, state, _entry} <-
           State.update_entry(
             socket.assigns.library_state,
             type,
             entry.id,
             socket.assigns.current_scope.actor.id,
             socket.assigns.library_can_manage_types?,
             params,
             entry.external_media_metadata
           ) do
      socket
      |> assign(:library_state, state)
      |> clear_edit()
      |> assign(:library_modal_mode, :detail)
      |> reset_placement_streams()
    else
      {:error, errors} when is_list(errors) ->
        socket
        |> assign(:library_edit_error, Enum.join(errors, " · "))
        |> assign(:library_edit_form, entry_form(params))

      _error ->
        put_error(socket, "You cannot edit that Library entry.")
    end
  end

  def cancel_edit(socket) do
    socket
    |> close_modal()
  end

  def sync_edit_mode(%{assigns: %{editing?: true}} = socket), do: reset_placement_streams(socket)

  def sync_edit_mode(socket) do
    socket
    |> clear_edit()
    |> reset_placement_streams()
  end

  def remove(socket, placement_id) do
    case find_placement(socket, placement_id) do
      nil ->
        put_error(socket, "That Library block is no longer available.")

      placement ->
        placements = Enum.reject(socket.assigns.library_placements, &(&1.id == placement.id))

        socket
        |> assign(:library_placements, placements)
        |> maybe_cancel_edit(placement.id)
        |> reset_placement_streams()
    end
  end

  def move(socket, placement_id, direction) when direction in ["up", "down"] do
    placement = find_placement(socket, placement_id)

    if placement do
      siblings = current_siblings(socket, placement.position)
      sibling_index = Enum.find_index(siblings, &(&1.id == placement.id))
      destination = sibling_index + if(direction == "up", do: -1, else: 1)

      case Enum.at(siblings, destination) do
        nil ->
          socket

        sibling ->
          socket |> swap_placements(placement.id, sibling.id) |> reset_placement_streams()
      end
    else
      put_error(socket, "That Library block is no longer available.")
    end
  end

  def move(socket, _placement_id, _direction) do
    put_error(socket, "That Library block cannot be moved.")
  end

  defp place_entry(socket, entry) do
    placement = %{
      entry_id: entry.id,
      id: "library-placement-#{System.unique_integer([:monotonic, :positive])}",
      page_id: socket.assigns.page.id,
      position: socket.assigns.add_block_position
    }

    socket
    |> assign(
      add_block_modal_open?: false,
      library_focused_placement_id: placement.id,
      library_placements: socket.assigns.library_placements ++ [placement]
    )
    |> close_modal()
    |> reset_placement_streams()
  end

  defp assign_picker_entries(socket, query) do
    entries =
      case selected_type(socket) do
        nil -> []
        type -> State.entries_for(socket.assigns.library_state, type.id)
      end

    normalized_query = query |> String.trim() |> String.downcase()

    entries =
      if normalized_query == "" do
        entries
      else
        Enum.filter(entries, fn entry ->
          type = State.find_type_by_id(socket.assigns.library_state, entry.type_id)

          type
          |> EntryPresentation.title(entry)
          |> String.downcase()
          |> String.contains?(normalized_query)
        end)
      end

    stream(socket, :library_picker_entries, entries, reset: true)
  end

  defp reset_placement_streams(socket) do
    top = socket |> current_siblings("top") |> decorate_placements()
    bottom = socket |> current_siblings("bottom") |> decorate_placements()

    socket
    |> stream(:library_top_placements, top, reset: true)
    |> stream(:library_bottom_placements, bottom, reset: true)
  end

  defp current_siblings(socket, position) do
    page_id = socket.assigns.page && socket.assigns.page.id

    Enum.filter(
      socket.assigns.library_placements,
      &(&1.page_id == page_id && &1.position == position)
    )
  end

  defp decorate_placements(placements) do
    last_index = length(placements) - 1

    placements
    |> Enum.with_index()
    |> Enum.map(fn {placement, index} ->
      Map.merge(placement, %{first?: index == 0, last?: index == last_index})
    end)
  end

  defp swap_placements(socket, first_id, second_id) do
    placements = socket.assigns.library_placements
    first_index = Enum.find_index(placements, &(&1.id == first_id))
    second_index = Enum.find_index(placements, &(&1.id == second_id))
    first = Enum.at(placements, first_index)
    second = Enum.at(placements, second_index)

    placements =
      placements
      |> List.replace_at(first_index, second)
      |> List.replace_at(second_index, first)

    assign(socket, :library_placements, placements)
  end

  defp maybe_cancel_edit(socket, placement_id) do
    if socket.assigns.library_edit_placement_id == placement_id,
      do: clear_edit(socket),
      else: socket
  end

  defp clear_edit(socket) do
    assign(socket,
      library_edit_error: nil,
      library_edit_form: nil,
      library_edit_placement_id: nil
    )
  end

  defp find_placement(socket, placement_id) do
    page_id = socket.assigns.page && socket.assigns.page.id

    Enum.find(
      socket.assigns.library_placements,
      &(&1.id == placement_id && &1.page_id == page_id)
    )
  end

  defp selected_entry(socket) do
    State.find_entry(socket.assigns.library_state, socket.assigns.library_selected_entry_id)
  end

  defp selected_type(socket) do
    State.find_type_by_id(socket.assigns.library_state, socket.assigns.library_selected_type_id)
  end

  defp manageable?(socket, entry) do
    State.can_manage_entry?(
      entry,
      socket.assigns.current_scope.actor.id,
      socket.assigns.library_can_manage_types?
    )
  end

  defp picker_form(query \\ ""), do: to_form(%{"query" => query}, as: :library_search)
  defp entry_form(params), do: to_form(params || %{}, as: :entry)

  defp put_error(socket, message), do: Phoenix.LiveView.put_flash(socket, :error, message)
end
