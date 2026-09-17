defmodule WikWeb.PageLive.BlockActions do
  @moduledoc false

  import Phoenix.Component

  alias Wik.Blocks
  alias WikWeb.PageLive.BlockEdit
  alias WikWeb.PageLive.LibraryEntries
  alias WikWeb.PageLive.PageState

  def add(socket, type_param) do
    socket = socket |> assign(add_block_modal_open?: false)
    scope = socket.assigns.current_scope
    space = scope.tenant
    page = socket.assigns.page
    position = socket |> add_block_position()

    case type_param do
      "linked_copy" ->
        socket |> start_linked_copy()

      _ ->
        case find_type(type_param) do
          nil ->
            socket |> Phoenix.LiveView.put_flash(:error, "Unknown block type")

          type ->
            socket |> add_block(space, page, type, position, scope)
        end
    end
  end

  def add_linked_copy(socket, block_id, position) do
    scope = socket.assigns.current_scope
    space = scope.tenant
    page = socket.assigns.page

    case Blocks.place_space_owned_block_on_page(
           space,
           block_id,
           page,
           position: position_param_to_atom(position),
           scope: scope
         ) do
      {:ok, _placement} ->
        socket |> assign(linked_copy_form: nil, linked_copy_error: nil)

      {:error, error} ->
        Utils.Log.scoped_error(scope, error, "place_space_owned_block_on_page failed")

        socket
        |> assign(
          :linked_copy_error,
          "Could not link block. Please ensure the block isn't already on this page."
        )
    end
  end

  def destroy(socket, placement_id) do
    scope = socket.assigns.current_scope

    case socket.assigns.page |> PageState.get_placement(placement_id) do
      {:ok, placement} ->
        case placement |> Blocks.destroy_placed_block(scope: scope) do
          :ok ->
            if socket.assigns.editing_block_id == placement.block.id do
              socket |> BlockEdit.clear()
            else
              socket
            end

          {:error, error} ->
            Utils.Log.scoped_error(scope, error, "destroy_placed_block failed")
            socket |> Phoenix.LiveView.put_flash(:error, "Could not remove block")
        end

      {:error, :not_found} ->
        socket |> stale_block_flash()
    end
  end

  def move_down(socket, placement_id) do
    scope = socket.assigns.current_scope

    case socket.assigns.page |> PageState.get_placement(placement_id) do
      {:ok, placement} ->
        case placement |> Blocks.move_placed_block_down(scope: scope) do
          {:ok, _placement} ->
            socket

          {:error, error} ->
            Utils.Log.scoped_error(scope, error, "move_placed_block_down failed")
            socket |> Phoenix.LiveView.put_flash(:error, "Could not move block")
        end

      {:error, :not_found} ->
        socket |> stale_block_flash()
    end
  end

  def move_up(socket, placement_id) do
    scope = socket.assigns.current_scope

    case socket.assigns.page |> PageState.get_placement(placement_id) do
      {:ok, placement} ->
        case placement |> Blocks.move_placed_block_up(scope: scope) do
          {:ok, _placement} ->
            socket

          {:error, error} ->
            Utils.Log.scoped_error(scope, error, "move_placed_block_up failed")
            socket |> Phoenix.LiveView.put_flash(:error, "Could not move block")
        end

      {:error, :not_found} ->
        socket |> stale_block_flash()
    end
  end

  def save_edit(socket, block_id, params) do
    scope = socket.assigns.current_scope

    case socket.assigns.page |> PageState.get_block(block_id) do
      {:ok, block} ->
        case block
             |> Blocks.update_block(params, scope: scope) do
          {:ok, _block} ->
            socket
            |> BlockEdit.clear()
            |> assign(:editing?, false)

          {:error, error} ->
            Utils.Log.scoped_error(scope, error, "save block failed")

            socket
            |> Phoenix.LiveView.put_flash(:error, "Could not save block")
            |> BlockEdit.continue(block_id, block, params)
        end

      {:error, :not_found} ->
        socket
        |> BlockEdit.clear()
        |> stale_block_flash()
    end
  end

  def start_edit(socket, block_id) do
    case socket.assigns.page |> PageState.get_block(block_id) do
      {:ok, %{type: :library_entry} = block} ->
        open_library_entry(socket, block)

      {:ok, block} ->
        start_standard_edit(socket, block)

      {:error, :not_found} ->
        stale_block_flash(socket)
    end
  end

  def toggle_aside(socket, placement_id) do
    scope = socket.assigns.current_scope

    case socket.assigns.page |> PageState.get_placement(placement_id) do
      {:ok, placement} ->
        case placement |> Blocks.toggle_placed_block_aside(scope: scope) do
          {:ok, _placement} ->
            socket

          {:error, error} ->
            Utils.Log.scoped_error(scope, error, "toggle_placed_block_aside failed")
            socket |> Phoenix.LiveView.put_flash(:error, "Could not update block layout")
        end

      {:error, :not_found} ->
        socket |> stale_block_flash()
    end
  end

  defp add_block(socket, space, page, type, position, scope) do
    case space
         |> Blocks.create_space_owned_block_on_page(
           page,
           %{type: type},
           position: position,
           scope: scope
         ) do
      {:ok, block} ->
        BlockEdit.start(socket, block)

      {:error, error} ->
        Utils.Log.scoped_error(scope, error, "create_space_owned_block_on_page failed")
        socket |> Phoenix.LiveView.put_flash(:error, "Could not add block to page")
    end
  end

  defp start_linked_copy(socket) do
    position = socket.assigns.add_block_position

    socket
    |> assign(
      :linked_copy_form,
      Phoenix.Component.to_form(%{"block_id" => nil, "position" => position}, as: :linked_copy)
    )
    |> assign(:linked_copy_error, nil)
  end

  defp add_block_position(%{assigns: %{add_block_position: "top"}}), do: :top
  defp add_block_position(%{assigns: %{add_block_position: "bottom"}}), do: :bottom

  defp position_param_to_atom("top"), do: :top
  defp position_param_to_atom("bottom"), do: :bottom

  defp find_type(type_param) do
    Blocks.types_available()
    |> Enum.find_value(&if("#{&1.type}" == type_param, do: &1.type))
  end

  defp open_library_entry(socket, block) do
    case Wik.Library.get_block_reference(block.id, scope: socket.assigns.current_scope) do
      {:ok, nil} ->
        Phoenix.LiveView.put_flash(socket, :error, "That Library entry is no longer available")

      {:ok, reference} ->
        LibraryEntries.open_for_edit(socket, reference.entry_id)

      {:error, error} ->
        Utils.Log.scoped_error(
          socket.assigns.current_scope,
          error,
          "load Library block reference failed"
        )

        Phoenix.LiveView.put_flash(socket, :error, "That Library entry is no longer available")
    end
  end

  defp start_standard_edit(socket, block) do
    case Map.get(socket.assigns.locks, block.id) do
      nil ->
        BlockEdit.start(socket, block)

      %{user: user} ->
        Phoenix.LiveView.put_flash(socket, :error, "#{user} is already editing this block")
    end
  end

  defp stale_block_flash(socket) do
    socket |> Phoenix.LiveView.put_flash(:error, "That block is no longer available")
  end
end
