defmodule WikWeb.PageLive.BlockInfo do
  @moduledoc false

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [put_flash: 3]

  alias WikWeb.PageLive.PageState

  def hide(socket) do
    assign(socket, block_info_placement: nil, block_info_author_membership: nil)
  end

  def show(socket, placement_id) do
    scope = socket.assigns.current_scope

    case socket.assigns.page |> PageState.get_placement(placement_id) do
      {:ok, placement} ->
        show_placement(socket, placement, scope)

      {:error, :not_found} ->
        socket
        |> put_flash(:error, "That block is no longer available")
        |> hide()
    end
  end

  defp show_placement(socket, placement, scope) do
    case load_placement(placement, scope) do
      {:ok, placement} ->
        assign(socket,
          block_info_placement: placement,
          block_info_author_membership: load_author_membership(placement, scope)
        )

      {:error, error} ->
        Utils.Log.scoped_error(scope, error, "load_block_info_placement failed")
        hide(socket)
    end
  end

  defp load_placement(nil, _scope), do: {:error, :not_found}

  defp load_placement(placement, scope) do
    placement |> Ash.load([block: [:author, :placements]], scope: scope)
  end

  defp load_author_membership(placement, scope) do
    case Wik.Accounts.get_membership(scope.tenant, placement.block.author) do
      {:ok, membership} ->
        membership

      {:error, error} ->
        Utils.Log.scoped_error(scope, error, "load_block_info_author_membership failed")
        nil
    end
  end
end
