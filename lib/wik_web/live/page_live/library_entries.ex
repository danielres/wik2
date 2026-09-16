defmodule WikWeb.PageLive.LibraryEntries do
  @moduledoc false

  import Phoenix.Component, only: [assign: 2, assign: 3, to_form: 2]
  import Phoenix.LiveView, only: [start_async: 3, stream: 4]

  alias Wik.Library
  alias Wik.Tags
  alias WikWeb.LibraryPrototypeLive.EntryFormMedia
  alias WikWeb.LibraryPrototypeLive.EntryPresentation
  alias WikWeb.LibraryPrototypeLive.ExternalMedia
  alias WikWeb.LibraryPrototypeLive.State
  alias WikWeb.PageLive.PageState
  alias WikWeb.TenantContext

  def assign_defaults(socket) do
    state = Wik.Library.page_snapshot(socket.assigns.current_scope)

    socket
    |> assign(
      library_can_manage_types?:
        TenantContext.space_admin?(socket.assigns.current_scope, socket.assigns.tenant_context),
      library_edit_error: nil,
      library_edit_form: nil,
      library_entry_form_media: EntryFormMedia.reset(),
      library_entry_error: nil,
      library_entry_form: nil,
      library_insert_position: nil,
      library_modal_mode: nil,
      library_picker_form: picker_form(),
      library_selected_entry_id: nil,
      library_selected_playlist_video_id: nil,
      library_selected_type_id: nil,
      library_state: state,
      library_topic_form: nil,
      library_topics: load_topics(socket.assigns.current_scope)
    )
    |> sync_subscriptions(state)
    |> stream(:library_picker_entries, [], reset: true)
  end

  def sync_page(socket) do
    state = Wik.Library.page_snapshot(socket.assigns.current_scope)

    socket
    |> assign(:library_state, state)
    |> sync_subscriptions(state)
    |> close_modal()
  end

  def refresh(socket) do
    state = Wik.Library.page_snapshot(socket.assigns.current_scope)

    socket =
      socket
      |> assign(:library_state, state)
      |> sync_subscriptions(state)

    case socket.assigns.library_modal_mode do
      :picker ->
        query = socket.assigns.library_picker_form[:query].value || ""
        stream_picker_entries(socket, socket.assigns.library_selected_type_id, query)

      mode when mode in [:detail, :edit] ->
        if State.find_entry(state, socket.assigns.library_selected_entry_id) do
          socket
        else
          close_modal(socket)
        end

      _other ->
        socket
    end
  end

  def close_modal(socket) do
    socket
    |> assign(
      library_edit_error: nil,
      library_edit_form: nil,
      library_entry_form_media: EntryFormMedia.reset(),
      library_entry_error: nil,
      library_entry_form: nil,
      library_insert_position: nil,
      library_modal_mode: nil,
      library_picker_form: picker_form(),
      library_selected_entry_id: nil,
      library_selected_playlist_video_id: nil,
      library_selected_type_id: nil,
      library_topic_form: nil
    )
    |> stream(:library_picker_entries, [], reset: true)
  end

  def start_insert(socket, type_id, position) when position in ["top", "bottom"] do
    socket
    |> assign(add_block_modal_open?: false, library_insert_position: position)
    |> open_picker(type_id)
  end

  defp start_create(socket, type_id) do
    case State.find_type_by_id(socket.assigns.library_state, type_id) do
      nil ->
        put_error(socket, "That Library type is no longer available.")

      type ->
        if State.can_create_entry?(type, socket.assigns.library_can_manage_types?) do
          assign(socket,
            library_entry_error: nil,
            library_entry_form: entry_form(nil),
            library_modal_mode: :new,
            library_selected_type_id: type.id
          )
        else
          put_error(socket, "You cannot add entries to that Library type.")
        end
    end
  end

  def start_picker_create(socket),
    do: start_create(socket, socket.assigns.library_selected_type_id)

  defp open_picker(socket, type_id) do
    case State.find_type_by_id(socket.assigns.library_state, type_id) do
      nil ->
        put_error(socket, "That Library type is no longer available.")

      type ->
        socket
        |> assign(
          library_entry_error: nil,
          library_modal_mode: :picker,
          library_picker_form: picker_form(),
          library_selected_type_id: type.id
        )
        |> stream_picker_entries(type.id, "")
    end
  end

  def search_picker(socket, query) do
    socket
    |> assign(:library_picker_form, picker_form(query))
    |> stream_picker_entries(socket.assigns.library_selected_type_id, query)
  end

  def select_picker_entry(socket, entry_id) do
    case State.find_entry(socket.assigns.library_state, entry_id) do
      %{type_id: type_id} = entry when type_id == socket.assigns.library_selected_type_id ->
        insert_entry_block(socket, entry)

      _missing ->
        put_error(socket, "That Library entry is no longer available.")
    end
  end

  def change_create(socket, params), do: assign(socket, :library_entry_form, entry_form(params))

  def create(socket, params) do
    type = selected_type(socket)
    actor_id = socket.assigns.current_scope.actor.id

    case type &&
           State.create_entry(
             socket.assigns.library_state,
             type,
             actor_id,
             socket.assigns.library_can_manage_types?,
             params
           ) do
      {:ok, state, entry} ->
        socket
        |> assign(:library_state, state)
        |> insert_entry_block(entry)

      {:error, errors} when is_list(errors) ->
        assign(socket,
          library_entry_error: Enum.join(errors, " · "),
          library_entry_form: entry_form(params)
        )

      _error ->
        put_error(socket, "You cannot add entries to that Library type.")
    end
  end

  def show(socket, entry_id) do
    case State.find_entry(socket.assigns.library_state, entry_id) do
      nil ->
        put_error(socket, "That Library entry is no longer available.")

      entry ->
        assign(socket,
          library_edit_error: nil,
          library_entry_form_media: EntryFormMedia.reset(),
          library_modal_mode: :detail,
          library_selected_entry_id: entry.id,
          library_selected_playlist_video_id: nil,
          library_selected_type_id: entry.type_id
        )
    end
  end

  def open_for_edit(socket, entry_id) do
    case State.find_entry(socket.assigns.library_state, entry_id) do
      nil ->
        put_error(socket, "That Library entry is no longer available.")

      entry ->
        if manageable?(socket, entry),
          do: start_edit(socket, entry.id),
          else: show(socket, entry.id)
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

  def start_edit(socket, entry_id) do
    entry = State.find_entry(socket.assigns.library_state, entry_id)

    if entry && manageable?(socket, entry) do
      assign(socket,
        library_edit_error: nil,
        library_edit_form: entry_form(entry.values),
        library_entry_form_media: EntryFormMedia.reset(entry.external_media_metadata),
        library_modal_mode: :edit,
        library_selected_entry_id: entry.id,
        library_selected_playlist_video_id: nil,
        library_selected_type_id: entry.type_id
      )
    else
      put_error(socket, "You cannot edit that Library entry.")
    end
  end

  def change_edit(socket, params, event) do
    target = get_in(event, ["_target", Access.at(1)])

    case EntryFormMedia.change(
           socket.assigns.library_entry_form_media,
           socket.assigns.library_edit_form.params,
           params,
           target,
           selected_type(socket)
         ) do
      {:ok, params, media_state} ->
        assign_entry_form_media(socket, params, media_state)

      {:resolve, params, media, media_state} ->
        resolve_external_media(socket, params, media, media_state)
    end
  end

  def save_edit(socket, params) do
    entry = selected_entry(socket)
    type = selected_type(socket)

    case entry && type &&
           State.update_entry(
             socket.assigns.library_state,
             type,
             entry.id,
             socket.assigns.current_scope.actor.id,
             socket.assigns.library_can_manage_types?,
             params,
             socket.assigns.library_entry_form_media.external_metadata
           ) do
      {:ok, state, entry} ->
        assign(socket,
          library_edit_error: nil,
          library_edit_form: nil,
          library_entry_form_media: EntryFormMedia.reset(),
          library_modal_mode: :detail,
          library_selected_entry_id: entry.id,
          library_state: state
        )

      {:error, errors} when is_list(errors) ->
        assign(socket,
          library_edit_error: Enum.join(errors, " · "),
          library_edit_form: entry_form(params)
        )

      _error ->
        put_error(socket, "You cannot edit that Library entry.")
    end
  end

  def cancel_create(socket) do
    open_picker(socket, socket.assigns.library_selected_type_id)
  end

  def cancel_edit(socket), do: close_modal(socket)

  def delete(socket, entry_id) do
    entry = State.find_entry(socket.assigns.library_state, entry_id)
    type = entry && State.find_type_by_id(socket.assigns.library_state, entry.type_id)

    if entry && type && manageable?(socket, entry) do
      case State.delete_entry(
             socket.assigns.library_state,
             type.id,
             entry.id,
             socket.assigns.current_scope.actor.id,
             socket.assigns.library_can_manage_types?
           ) do
        {:ok, state, _entry} ->
          socket |> assign(:library_state, state) |> close_modal()

        {:error, message} when is_binary(message) ->
          assign(socket, :library_edit_error, message)

        {:error, _reason} ->
          assign(socket, :library_edit_error, "You cannot delete that Library entry.")
      end
    else
      assign(socket, :library_edit_error, "You cannot delete that Library entry.")
    end
  end

  def open_topic_form(socket) do
    assign(socket, :library_topic_form, topic_form())
  end

  def close_topic_form(socket), do: assign(socket, :library_topic_form, nil)

  def save_topic(socket, topic_id, relevancy) do
    entry = selected_entry(socket)
    membership_id = current_membership_id(socket)
    topic = Enum.find(socket.assigns.library_topics, &(&1.id == topic_id))

    result =
      if entry && membership_id && topic do
        State.upsert_topic_contribution(
          socket.assigns.library_state,
          entry.id,
          membership_id,
          topic_id,
          relevancy
        )
      else
        {:error, "Choose a topic and relevance from 1 to 10."}
      end

    case result do
      {:ok, state, _contribution} ->
        assign(socket, library_state: state, library_topic_form: nil)

      {:error, message} ->
        put_error(socket, message)
    end
  end

  def remove_topic(socket, topic_id) do
    entry = selected_entry(socket)

    case State.remove_topic_contribution(
           socket.assigns.library_state,
           entry.id,
           current_membership_id(socket),
           topic_id
         ) do
      {:ok, state} -> assign(socket, :library_state, state)
      {:error, :not_found} -> socket
    end
  end

  def dismiss_topic(socket, topic_id) do
    entry = selected_entry(socket)

    assign(
      socket,
      :library_state,
      State.dismiss_automatic_topic(socket.assigns.library_state, entry.id, topic_id)
    )
  end

  def handle_external_media_result(socket, request_id, result) do
    form = socket.assigns.library_edit_form

    if form &&
         EntryFormMedia.matching_request?(
           socket.assigns.library_entry_form_media,
           request_id,
           form.params
         ) do
      {params, media_state} =
        EntryFormMedia.apply_result(
          socket.assigns.library_entry_form_media,
          form.params,
          result
        )

      assign_entry_form_media(socket, params, media_state)
    else
      socket
    end
  end

  def handle_external_media_exit(socket, request_id) do
    if EntryFormMedia.request_id(socket.assigns.library_entry_form_media) == request_id do
      assign(
        socket,
        :library_entry_form_media,
        EntryFormMedia.fail(socket.assigns.library_entry_form_media)
      )
    else
      socket
    end
  end

  defp insert_entry_block(socket, entry) do
    position = position_to_atom(socket.assigns.library_insert_position)

    case Library.create_entry_block_on_page(entry, socket.assigns.page,
           position: position,
           scope: socket.assigns.current_scope
         ) do
      {:ok, _block} ->
        socket
        |> close_modal()
        |> PageState.reload()
        |> assign(:editing?, false)

      {:error, error} ->
        Utils.Log.scoped_error(socket.assigns.current_scope, error, "create Library block failed")
        put_error(socket, "Could not add Library entry to the page.")
    end
  end

  defp position_to_atom("top"), do: :top
  defp position_to_atom("bottom"), do: :bottom

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

  defp resolve_external_media(socket, params, media, media_state) do
    request_id = System.unique_integer([:monotonic, :positive])
    media_state = EntryFormMedia.begin_resolution(media_state, media, request_id)

    socket
    |> assign_entry_form_media(params, media_state)
    |> start_async({:library_entry_external_media, request_id}, fn ->
      ExternalMedia.resolve(media)
    end)
  end

  defp assign_entry_form_media(socket, params, media_state) do
    socket
    |> assign(:library_edit_form, entry_form(params))
    |> assign(:library_entry_form_media, media_state)
  end

  defp current_membership_id(socket) do
    case socket.assigns.tenant_context do
      %{current_membership: %{id: id}} -> id
      _tenant_context -> nil
    end
  end

  defp stream_picker_entries(socket, type_id, query) do
    normalized_query = query |> to_string() |> String.trim() |> String.downcase()

    entries =
      socket.assigns.library_state.entries
      |> Map.values()
      |> Enum.filter(&(&1.type_id == type_id))
      |> Enum.filter(fn entry ->
        type = State.find_type_by_id(socket.assigns.library_state, type_id)

        normalized_query == "" or
          type
          |> EntryPresentation.title(entry)
          |> String.downcase()
          |> String.contains?(normalized_query)
      end)
      |> Enum.sort_by(&EntryPresentation.title(type_for_entry(socket, &1), &1))

    stream(socket, :library_picker_entries, entries, reset: true)
  end

  defp type_for_entry(socket, entry) do
    State.find_type_by_id(socket.assigns.library_state, entry.type_id)
  end

  defp sync_subscriptions(socket, state) do
    if Phoenix.LiveView.connected?(socket) do
      space_id = socket.assigns.current_scope.tenant.id
      subscribed_space_id = socket.assigns[:library_subscribed_space_id]

      if subscribed_space_id != space_id do
        if subscribed_space_id do
          WikWeb.Endpoint.unsubscribe("library_entry:space:#{subscribed_space_id}")
          WikWeb.Endpoint.unsubscribe("library_entry_type:space:#{subscribed_space_id}")
        end

        WikWeb.Endpoint.subscribe("library_entry:space:#{space_id}")
        WikWeb.Endpoint.subscribe("library_entry_type:space:#{space_id}")
      end

      type_ids = MapSet.new(state.types, & &1.id)
      subscribed_type_ids = socket.assigns[:library_subscribed_type_ids] || MapSet.new()

      type_ids
      |> MapSet.difference(subscribed_type_ids)
      |> Enum.each(&WikWeb.Endpoint.subscribe("library_field:type:#{&1}"))

      subscribed_type_ids
      |> MapSet.difference(type_ids)
      |> Enum.each(&WikWeb.Endpoint.unsubscribe("library_field:type:#{&1}"))

      assign(socket,
        library_subscribed_space_id: space_id,
        library_subscribed_type_ids: type_ids
      )
    else
      socket
    end
  end

  defp picker_form(query \\ ""),
    do: to_form(%{"query" => query}, as: :library_search)

  defp entry_form(params), do: to_form(params || %{}, as: :entry)
  defp topic_form, do: to_form(%{"relevancy" => "5", "topic_id" => ""}, as: :entry_topic)

  defp load_topics(scope) do
    case Tags.list_space_tags(scope) do
      {:ok, topics} -> topics
      {:error, _error} -> []
    end
  end

  defp put_error(socket, message), do: Phoenix.LiveView.put_flash(socket, :error, message)
end
