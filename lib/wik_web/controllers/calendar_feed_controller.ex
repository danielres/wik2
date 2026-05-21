defmodule WikWeb.CalendarFeedController do
  use WikWeb, :controller

  alias Wik.Accounts.User
  alias Wik.Events
  alias Wik.Events.Feeds.Serializer
  alias Wik.Events.Feeds.Token

  def show(conn, %{"token" => token}) do
    with {:ok, payload} <- Token.decode(token),
         {:ok, user} <- load_user(payload.user_id),
         {:ok, calendar_name, events} <- load_feed(payload, user) do
      ics = Serializer.to_ics(events, calendar_name: calendar_name)

      conn
      |> put_resp_header("content-type", "text/calendar; charset=utf-8")
      |> send_resp(200, ics)
    else
      _error ->
        send_resp(conn, 404, "Not found")
    end
  end

  defp load_user(user_id) do
    Ash.get(User, user_id, authorize?: false)
  end

  defp load_feed(%{feed_kind: :aggregate}, user) do
    with {:ok, events} <- Events.list_aggregate_feed_events(user) do
      {:ok, aggregate_calendar_name(user), events}
    end
  end

  defp load_feed(%{feed_kind: :space, space_id: space_id}, user) do
    with {:ok, %{events: events, space: space}} <- Events.get_space_feed(user, space_id) do
      {:ok, space_calendar_name(space), events}
    end
  end

  defp aggregate_calendar_name(user), do: "#{user} events"
  defp space_calendar_name(space), do: "#{space.name} events"
end
