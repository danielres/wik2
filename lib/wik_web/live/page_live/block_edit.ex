defmodule WikWeb.PageLive.BlockEdit do
  @moduledoc false

  import Phoenix.Component, only: [assign: 2, assign: 3, to_form: 2]

  alias Wik.Blocks
  alias WikWeb.PageLive.Locks

  def clear(socket) do
    socket
    |> assign(editing_block_id: nil, form_edit_block: nil)
    |> Locks.sync_presence()
  end

  def continue(socket, block_id, block, params) do
    socket
    |> assign(editing_block_id: block_id)
    |> assign_form(block, params)
    |> Locks.sync_presence()
  end

  def start(socket, block) do
    socket
    |> assign(editing_block_id: block.id)
    |> assign_form(block)
    |> Locks.sync_presence()
  end

  defp assign_form(socket, block, params \\ %{}) do
    page_tree = socket.assigns.page_tree

    form =
      block
      |> Blocks.block_to_form_params(params, page_tree)
      |> to_form(as: :block)

    socket |> assign(:form_edit_block, form)
  end
end
