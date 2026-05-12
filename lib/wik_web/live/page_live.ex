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

  on_mount {WikWeb.LiveUserAuth, :live_scope_required}
  on_mount {WikWeb.LiveUserAuth, :subscribe_presence}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        add_block_modal_open?: false,
        add_block_position: "bottom",
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
    {:noreply, socket |> PageState.reload()}
  end

  # Edit =======================================================================

  @impl true
  def handle_event("toggle_edit_mode", _params, socket) do
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
            {:noreply, socket |> assign(block_info_placement: placement)}

          {:error, error} ->
            Utils.Log.scoped_error(scope, error, "load_block_info_placement failed")
            {:noreply, socket |> assign(block_info_placement: nil)}
        end

      {:error, :not_found} ->
        {:noreply,
         socket
         |> Phoenix.LiveView.put_flash(:error, "That block is no longer available")
         |> assign(block_info_placement: nil)}
    end
  end

  @impl true
  def handle_event("hide_block_info", _params, socket) do
    {:noreply, socket |> assign(block_info_placement: nil)}
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

  defp load_block_info_placement(nil, _scope), do: {:error, :not_found}

  defp load_block_info_placement(placement, scope) do
    placement |> Ash.load([block: [:author, :placements]], scope: scope)
  end
end
