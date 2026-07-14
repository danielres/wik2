defmodule WikWeb.PageLive do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers

  alias WikWeb.Components
  alias WikWeb.Components.UI
  alias WikWeb.PageLive
  alias WikWeb.PageLive.BlockActions
  alias WikWeb.PageLive.BlockEdit
  alias WikWeb.PageLive.Locks
  alias WikWeb.PageLive.PageState
  alias WikWeb.Presence
  alias WikWeb.Presence.Handlers
  alias Wik.Tags
  alias Wik.Tags.Tag
  alias Wik.Tags.Tagging
  alias Wik.Tags.TopicSummaries

  on_mount {WikWeb.LiveUserAuth, :live_scope_required}
  on_mount {WikWeb.LiveUserAuth, :subscribe_presence}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        add_block_modal_open?: false,
        author_membership: nil,
        add_block_position: "bottom",
        block_info_author_membership: nil,
        block_history_placement: nil,
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
        page_topic_form: nil,
        page_topic_options: [],
        page_topic_summaries: [],
        page_taggings: [],
        page_tagging_topic: nil,
        page_tree: nil,
        path: nil
      )
      |> Locks.assign_locks()

    {:ok, socket}
  end

  defp has_area?(page, area), do: Enum.any?(page.block_placements, &(&1.area == area))

  # Presence ===================================================================

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
      |> sync_page_tagging_subscription()
      |> assign_page_topics()
      |> load_page_author_membership()
      |> Presence.track_in_liveview(url)
      |> Locks.assign_locks()

    {:noreply, socket}
  end

  # subscriptions ==============================================================

  @impl true
  def handle_info(%{topic: "block:" <> _block_id}, socket) do
    {:noreply, socket |> PageState.reload()}
  end

  @impl true
  def handle_info(%{topic: "block_placement:page:" <> _page_id}, socket) do
    {:noreply, socket |> PageState.reload() |> assign_page_topics()}
  end

  @impl true
  def handle_info(%{topic: topic}, socket) do
    page_id = socket.assigns.page && socket.assigns.page.id

    watched_topics =
      [Tag.space_pub_sub_topic(socket.assigns.current_scope.tenant.id)] ++
        if(page_id,
          do: [Tagging.target_pub_sub_topic("page", page_id)],
          else: []
        )

    if topic in watched_topics do
      {:noreply, assign_page_topics(socket)}
    else
      {:noreply, socket}
    end
  end

  # Edit =======================================================================

  @impl true
  def handle_event("toggle_edit_mode", _params, socket) do
    socket = socket |> assign(editing?: !socket.assigns.editing?)

    socket =
      if socket.assigns.editing?,
        do: socket,
        else: socket |> BlockEdit.clear() |> close_page_topic_form()

    {:noreply, socket}
  end

  @impl true
  def handle_event("page_topic_add_start", _params, socket) do
    {:noreply, open_page_topic_form(socket)}
  end

  @impl true
  def handle_event("page_topic_cancel", _params, socket) do
    {:noreply, close_page_topic_form(socket)}
  end

  @impl true
  def handle_event("page_topic_validate", %{"page_topic" => params}, socket) do
    {:noreply, assign(socket, :page_topic_form, page_topic_form(params))}
  end

  @impl true
  def handle_event("page_topic_submit", %{"page_topic" => params}, socket) do
    scope = socket.assigns.current_scope

    socket =
      with {:ok, tagging_params} <- parse_page_topic_params(params),
           %{} = membership <- current_membership(socket),
           %{} = page <- socket.assigns.page,
           {:ok, _tagging} <-
             Tags.upsert_tagging(
               page,
               membership,
               tagging_params.tag_id,
               %{dimensions: %{"relevancy" => tagging_params.relevancy_level}},
               scope: scope
             ) do
        socket
        |> close_page_topic_form()
        |> assign_page_topics()
      else
        {:error, message} when is_binary(message) ->
          assign_page_topic_form_error(socket, params, message)

        {:error, error} ->
          Utils.Log.scoped_error(scope, error, "page topic submit failed")
          assign_page_topic_form_error(socket, params, "Couldn't save that topic.")

        _other ->
          assign_page_topic_form_error(socket, params, "Couldn't save that topic.")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("page_topic_remove", %{"tag_id" => tag_id}, socket) do
    scope = socket.assigns.current_scope

    socket =
      with %{} = membership <- current_membership(socket),
           %{} = page <- socket.assigns.page,
           {:ok, _tagging} <- Tags.remove_tagging(page, membership, tag_id, scope: scope) do
        assign_page_topics(socket)
      else
        {:error, :not_found} ->
          assign_page_topics(socket)

        {:error, error} ->
          Utils.Log.scoped_error(scope, error, "page topic remove failed")
          socket

        _other ->
          socket
      end

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
  def handle_event("add_block_modal_open", _params, socket) do
    {:noreply, socket |> assign(add_block_modal_open?: true)}
  end

  @impl true
  def handle_event("add_block_modal_cancel", _params, socket) do
    {:noreply, socket |> assign(add_block_modal_open?: false)}
  end

  @impl true
  def handle_event("add_block_position_select", %{"position" => "top"}, socket) do
    {:noreply, socket |> assign(add_block_position: "top")}
  end

  @impl true
  def handle_event("add_block_position_select", %{"position" => "bottom"}, socket) do
    {:noreply, socket |> assign(add_block_position: "bottom")}
  end

  @impl true
  def handle_event("linked_copy_cancel", _params, socket) do
    {:noreply, socket |> assign(linked_copy_form: nil, linked_copy_error: nil)}
  end

  @impl true
  def handle_event(
        "linked_copy_submit",
        %{"linked_copy" => %{"block_id" => block_id, "position" => position}},
        socket
      ) do
    {:noreply, socket |> BlockActions.add_linked_copy(block_id, position)}
  end

  @impl true
  def handle_event("show_block_info", %{"placement_id" => placement_id}, socket) do
    scope = socket.assigns.current_scope

    case socket.assigns.page |> PageState.get_placement(placement_id) do
      {:ok, placement} ->
        case load_block_info_placement(placement, scope) do
          {:ok, placement} ->
            {:noreply,
             socket
             |> assign(block_info_placement: placement)
             |> assign(
               :block_info_author_membership,
               load_block_info_author_membership(placement, scope)
             )}

          {:error, error} ->
            Utils.Log.scoped_error(scope, error, "load_block_info_placement failed")

            {:noreply,
             socket |> assign(block_info_placement: nil, block_info_author_membership: nil)}
        end

      {:error, :not_found} ->
        {:noreply,
         socket
         |> Phoenix.LiveView.put_flash(:error, "That block is no longer available")
         |> assign(block_info_placement: nil, block_info_author_membership: nil)}
    end
  end

  @impl true
  def handle_event("hide_block_info", _params, socket) do
    {:noreply, socket |> assign(block_info_placement: nil, block_info_author_membership: nil)}
  end

  @impl true
  def handle_event("show_block_history", %{"placement_id" => placement_id}, socket) do
    case socket.assigns.page |> PageState.get_placement(placement_id) do
      {:ok, placement} ->
        {:noreply, assign(socket, block_history_placement: placement)}

      {:error, :not_found} ->
        {:noreply,
         socket |> Phoenix.LiveView.put_flash(:error, "That block is no longer available")}
    end
  end

  @impl true
  def handle_event("hide_block_history", _params, socket) do
    {:noreply, assign(socket, block_history_placement: nil)}
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
  def handle_event("toggle_block_aside", %{"placement_id" => placement_id}, socket) do
    {:noreply, socket |> BlockActions.toggle_aside(placement_id)}
  end

  defp assign_page_topics(%{assigns: %{page: nil}} = socket) do
    assign(socket,
      page_topic_options: [],
      page_topic_summaries: [],
      page_taggings: []
    )
  end

  defp assign_page_topics(%{assigns: %{page: page, current_scope: scope}} = socket) do
    if connected?(socket) do
      WikWeb.Endpoint.subscribe(Tag.space_pub_sub_topic(scope.tenant.id))
    end

    with {:ok, taggings} <- Tags.list_taggings(page, scope: scope),
         {:ok, tags} <- Tags.list_space_tags(scope) do
      assign(socket,
        page_topic_options: page_topic_options(tags, taggings, current_membership(socket)),
        page_topic_summaries: page_topic_summaries(taggings, current_membership(socket)),
        page_taggings: taggings
      )
    else
      {:error, error} ->
        Utils.Log.scoped_error(scope, error, "page topics load failed")

        assign(socket,
          page_topic_options: [],
          page_topic_summaries: [],
          page_taggings: []
        )
    end
  end

  defp sync_page_tagging_subscription(socket) do
    if connected?(socket) do
      current_topic =
        socket.assigns.page && Tagging.target_pub_sub_topic("page", socket.assigns.page.id)

      previous_topic = socket.assigns.page_tagging_topic

      cond do
        current_topic == previous_topic ->
          socket

        true ->
          if previous_topic, do: WikWeb.Endpoint.unsubscribe(previous_topic)
          if current_topic, do: WikWeb.Endpoint.subscribe(current_topic)

          assign(socket, :page_tagging_topic, current_topic)
      end
    else
      socket
    end
  end

  defp page_topic_options(tags, _taggings, nil), do: tags

  defp page_topic_options(tags, taggings, membership) do
    existing_tag_ids =
      taggings
      |> Enum.filter(&(&1.tagged_by_membership_id == membership.id))
      |> MapSet.new(& &1.tag_id)

    Enum.reject(tags, &MapSet.member?(existing_tag_ids, &1.id))
  end

  defp page_topic_summaries(taggings, current_membership) do
    TopicSummaries.build(taggings, current_membership)
  end

  defp current_membership(socket) do
    socket.assigns.tenant_context && socket.assigns.tenant_context.current_membership
  end

  defp open_page_topic_form(socket) do
    assign(socket, :page_topic_form, page_topic_form())
  end

  defp close_page_topic_form(socket) do
    assign(socket, :page_topic_form, nil)
  end

  defp page_topic_form(params \\ %{}) do
    params
    |> normalize_page_topic_form()
    |> to_form(as: :page_topic)
  end

  defp normalize_page_topic_form(params) do
    %{
      "relevancy_level" => Map.get(params, "relevancy_level", "5"),
      "tag_id" => Map.get(params, "tag_id", "")
    }
  end

  defp parse_page_topic_params(params) do
    with tag_id when is_binary(tag_id) and tag_id != "" <- Map.get(params, "tag_id"),
         {:ok, relevancy_level} <- parse_level(params, "relevancy_level") do
      {:ok, %{relevancy_level: relevancy_level, tag_id: tag_id}}
    else
      _ -> {:error, "Select a topic and enter a valid relevancy level."}
    end
  end

  defp parse_level(params, key) do
    params
    |> Map.get(key, "0")
    |> Integer.parse()
    |> case do
      {level, ""} when level in 1..10 -> {:ok, level}
      _other -> :error
    end
  end

  defp assign_page_topic_form_error(socket, params, message) do
    socket
    |> assign(:page_topic_form, page_topic_form(params))
    |> put_flash(:error, message)
  end

  defp load_block_info_placement(nil, _scope), do: {:error, :not_found}

  defp load_block_info_placement(placement, scope) do
    placement |> Ash.load([block: [:author, :placements]], scope: scope)
  end

  defp load_block_info_author_membership(placement, scope) do
    case Wik.Accounts.get_membership(scope.tenant, placement.block.author) do
      {:ok, membership} ->
        membership

      {:error, error} ->
        Utils.Log.scoped_error(scope, error, "load_block_info_author_membership failed")
        nil
    end
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
