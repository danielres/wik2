defmodule WikWeb.PageLive.BlockHistory do
  @moduledoc false

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [put_flash: 3]

  alias WikWeb.PageLive.PageState

  def hide(socket) do
    assign(socket, block_history_placement: nil)
  end

  def show(socket, placement_id) do
    case socket.assigns.page |> PageState.get_placement(placement_id) do
      {:ok, placement} ->
        assign(socket, block_history_placement: placement)

      {:error, :not_found} ->
        put_flash(socket, :error, "That block is no longer available")
    end
  end
end
