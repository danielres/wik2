defmodule QblogWeb.PageLive.BlockEdit do
  @moduledoc false

  import Phoenix.Component, only: [assign: 2, assign: 3, to_form: 2]

  alias Qblog.Blocks
  alias QblogWeb.PageLive.Locks

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

  defp assign_form(socket, block) do
    form = block |> Blocks.block_to_form_params() |> to_form(as: :block)
    socket |> assign(:form_edit_block, form)
  end

  defp assign_form(socket, block, params) do
    form = block |> Blocks.block_to_form_params(params) |> to_form(as: :block)
    socket |> assign(:form_edit_block, form)
  end
end
