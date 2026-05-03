defmodule WikWeb.Presence.Handlers do
  @moduledoc """
  Shared handlers for group-scoped presence updates in LiveViews.
  """

  import Phoenix.Component, only: [assign: 3]

  alias WikWeb.Presence

  @stale_presence_ttl_ms 250

  def handle_presence_change(socket) do
    case socket.assigns[:current_scope] do
      %{tenant: %{id: group_id}} ->
        presences = Presence.list_online_users_in_group(group_id)
        stale_presences = socket.assigns[:stale_presences] || %{}

        socket
        |> assign(:presences, merge_presences(presences, stale_presences))
        |> assign(:stale_presences, stale_presences)

      _ ->
        assign(socket, :presences, [])
    end
  end

  defmacro __using__(_opts) do
    quote do
      def handle_presence_change(socket) do
        WikWeb.Presence.Handlers.handle_presence_change(socket)
      end

      defoverridable handle_presence_change: 1

      @impl true
      def handle_info({WikWeb.Presence, {:join, presence}}, socket) do
        socket =
          socket
          |> WikWeb.Presence.Handlers.forget_stale_presence(presence.id)
          |> handle_presence_change()

        {:noreply, socket}
      end

      @impl true
      def handle_info({WikWeb.Presence, {:leave, presence}}, socket) do
        socket =
          socket
          |> WikWeb.Presence.Handlers.delay_presence_removal(presence)
          |> handle_presence_change()

        {:noreply, socket}
      end

      @impl true
      def handle_info({WikWeb.Presence, {:update, %{id: id}}}, socket) do
        socket =
          socket
          |> WikWeb.Presence.Handlers.forget_stale_presence(id)
          |> handle_presence_change()

        {:noreply, socket}
      end

      @impl true
      def handle_info({WikWeb.Presence, {:remove_stale, presence_id}}, socket) do
        socket =
          socket
          |> WikWeb.Presence.Handlers.forget_stale_presence(presence_id)
          |> handle_presence_change()

        {:noreply, socket}
      end
    end
  end

  def delay_presence_removal(socket, presence) do
    Process.send_after(self(), {Presence, {:remove_stale, presence.id}}, @stale_presence_ttl_ms)

    socket
    |> assign(:stale_presences, Map.put(stale_presences(socket), presence.id, presence))
  end

  def forget_stale_presence(socket, presence_id) do
    socket
    |> assign(:stale_presences, Map.delete(stale_presences(socket), presence_id))
  end

  defp merge_presences(presences, stale_presences) do
    live_presence_ids = presences |> MapSet.new(& &1.id)

    stale_presences
    |> Map.values()
    |> Enum.reject(&MapSet.member?(live_presence_ids, &1.id))
    |> then(&(presences ++ &1))
    |> Enum.sort_by(& &1.id)
  end

  defp stale_presences(socket), do: socket.assigns[:stale_presences] || %{}
end
