defmodule WikWeb.PageLive.Locks do
  @moduledoc false

  import Phoenix.Component, only: [assign: 2]

  alias WikWeb.Presence

  def assign_locks(socket) do
    presences = socket.assigns.presences
    actor_id = socket.assigns.current_scope.actor.id
    tab_id = socket.assigns.tab_id
    locks = Presence.presences_to_locks(presences, actor_id, tab_id)

    socket |> assign(locks: locks)
  end

  def sync_presence(socket) do
    case {Phoenix.LiveView.connected?(socket), socket.assigns[:presence_path],
          socket.assigns[:current_scope]} do
      {true, path, %{actor: user, tenant: group}} when is_binary(path) ->
        _ =
          Presence.track_user_presence(
            user,
            path,
            group.id,
            editing_block_id: socket.assigns.editing_block_id,
            tab_id: socket.assigns.tab_id
          )

        socket

      _ ->
        socket
    end
  end
end
