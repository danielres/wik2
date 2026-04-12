defmodule QblogWeb.Presence.Handlers do
  @moduledoc """
  Shared handlers for group-scoped presence updates in LiveViews.
  """

  import Phoenix.Component, only: [assign: 3]

  alias QblogWeb.Presence

  def handle_presence_change(socket) do
    case socket.assigns[:current_scope] do
      %{tenant: %{id: group_id}} ->
        assign(socket, :presences, Presence.list_online_users_in_group(group_id))

      _ ->
        assign(socket, :presences, [])
    end
  end

  defmacro __using__(_opts) do
    quote do
      def handle_presence_change(socket) do
        QblogWeb.Presence.Handlers.handle_presence_change(socket)
      end

      defoverridable handle_presence_change: 1

      @impl true
      def handle_info({QblogWeb.Presence, {:join, _presence}}, socket) do
        {:noreply, handle_presence_change(socket)}
      end

      @impl true
      def handle_info({QblogWeb.Presence, {:leave, _presence}}, socket) do
        {:noreply, handle_presence_change(socket)}
      end

      @impl true
      def handle_info({QblogWeb.Presence, {:update, %{id: _id, meta: _meta}}}, socket) do
        {:noreply, handle_presence_change(socket)}
      end
    end
  end
end
