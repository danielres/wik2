defmodule QblogWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """
  alias Qblog.Accounts

  import Phoenix.Component
  use QblogWeb, :verified_routes

  # This is used for nested liveviews to fetch the current user.
  # To use, place the following at the top of that liveview:
  # on_mount {QblogWeb.LiveUserAuth, :current_user}
  def on_mount(:current_user, _params, session, socket) do
    {:cont, AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)}
  end

  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      current_user = socket.assigns.current_user
      current_scope = %Qblog.Scope{actor: current_user, tenant: nil}
      socket = socket |> assign(current_scope: current_scope)

      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_scope_required, params, _session, socket) do
    current_user = socket.assigns[:current_user]

    if current_user do
      group_name = params["group_name"]

      case group_name |> Accounts.get_group_by_name(actor: current_user) do
        {:ok, group} ->
          current_scope = %Qblog.Scope{actor: current_user, tenant: group}
          socket = socket |> assign(current_scope: current_scope)
          {:cont, socket}

        _ ->
          socket = Phoenix.LiveView.put_flash(socket, :error, ~s(Group "#{group_name}" not found))
          {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
      end
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:subscribe_presence, _params, _session, socket) do
    socket =
      socket
      |> assign_new(:tab_id, fn ->
        System.unique_integer([:monotonic, :positive]) |> Integer.to_string()
      end)

    socket =
      case {Phoenix.LiveView.connected?(socket), socket.assigns[:current_scope]} do
        {true, %{tenant: %{id: group_id}}} ->
          :ok = QblogWeb.Presence.subscribe_to_group(group_id)
          assign(socket, :presences, QblogWeb.Presence.list_online_users_in_group(group_id))

        _ ->
          assign(socket, :presences, [])
      end

    {:cont, socket}
  end
end
