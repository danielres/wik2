defmodule WikWeb.PageLive.EditMode do
  @moduledoc false

  import Phoenix.Component, only: [assign: 2]

  alias WikWeb.PageLive.BlockEdit
  alias WikWeb.PageLive.PageTopics

  def toggle(socket) do
    socket = socket |> assign(editing?: !socket.assigns.editing?)

    if socket.assigns.editing?,
      do: socket,
      else: socket |> BlockEdit.clear() |> PageTopics.close_form()
  end
end
