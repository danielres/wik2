defmodule WikWeb.PageLive.Components.BlockHistory do
  use WikWeb, :live_component

  alias Wik.Blocks
  alias WikWeb.PageLive.Components.BlockHistoryModal

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign_new(:loaded_placement_id, fn -> nil end)
      |> assign_new(:selected_text, fn -> nil end)
      |> assign_new(:selected_version, fn -> nil end)
      |> assign_new(:total_versions, fn -> 0 end)
      |> assign(assigns)
      |> refresh_placement_history()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <BlockHistoryModal.render
        :if={@selected_version}
        page_tree={@page_tree}
        placement={@placement}
        scope={@scope}
        selected_text={@selected_text}
        selected_version={@selected_version}
        total_versions={@total_versions}
        nav_target={@myself}
      />
    </div>
    """
  end

  @impl true
  def handle_event("navigate", %{"direction" => direction}, socket) do
    block = socket.assigns.placement.block
    current_version = socket.assigns.selected_version
    scope = socket.assigns.scope

    result =
      case direction do
        "first" -> load_version_oldest(block, scope)
        "prev" -> load_version_prev(block, current_version, scope)
        "next" -> load_version_next(block, current_version, scope)
        "last" -> load_version_latest(block, scope)
      end

    case result do
      {:ok, nil} ->
        {:noreply, socket}

      {:ok, version} ->
        {:noreply, assign_selected_version(socket, block, version, scope)}

      {:error, error} ->
        Utils.Log.scoped_error(scope, error, "load_version failed")
        {:noreply, socket}
    end
  end

  defp refresh_placement_history(
         %{assigns: %{placement: placement, loaded_placement_id: placement_id}} = socket
       )
       when placement.id == placement_id do
    socket
  end

  defp refresh_placement_history(socket) do
    scope = socket.assigns.scope
    placement = socket.assigns.placement

    case Blocks.count_versions(placement.block, scope: scope) do
      {:ok, total_versions} when total_versions > 0 ->
        socket
        |> assign(
          loaded_placement_id: placement.id,
          total_versions: total_versions
        )
        |> load_latest_selected_version(placement.block, scope)

      {:ok, _total_versions} ->
        socket

      {:error, error} ->
        Utils.Log.scoped_error(scope, error, "count_versions failed")
        socket
    end
  end

  defp load_latest_selected_version(socket, block, scope) do
    case Blocks.load_version_latest(block, scope: scope) do
      {:ok, %{} = selected_version} ->
        assign_selected_version(socket, block, selected_version, scope)

      {:ok, nil} ->
        socket

      {:error, error} ->
        Utils.Log.scoped_error(scope, error, "load_version_latest failed")
        socket
    end
  end

  defp load_version_prev(block, current_version, scope),
    do: Blocks.load_version_prev(block, current_version, scope: scope)

  defp load_version_next(block, current_version, scope),
    do: Blocks.load_version_next(block, current_version, scope: scope)

  defp load_version_oldest(block, scope),
    do: Blocks.load_version_oldest(block, scope: scope)

  defp load_version_latest(block, scope),
    do: Blocks.load_version_latest(block, scope: scope)

  defp assign_selected_version(socket, block, version, scope) do
    case Blocks.version_to_text(block, version, scope: scope) do
      {:ok, selected_text} ->
        assign(socket,
          selected_text: selected_text,
          selected_version: version
        )

      {:error, error} ->
        Utils.Log.scoped_error(scope, error, "block version_to_text failed")
        socket
    end
  end
end
