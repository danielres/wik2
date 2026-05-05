defmodule WikWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """
  @dev_routes? Application.compile_env(:wik, :dev_routes, false)

  alias Wik.Access
  alias Wik.Accounts
  alias Wik.Accounts.GroupUserRelation
  alias WikWeb.Context
  alias WikWeb.ErrorTrackerContext

  import Phoenix.Component
  import Phoenix.LiveView, only: [attach_hook: 4, get_connect_params: 1]
  use WikWeb, :verified_routes

  # This is used for nested liveviews to fetch the current user.
  # To use, place the following at the top of that liveview:
  # on_mount {WikWeb.LiveUserAuth, :current_user}
  def on_mount(:current_user, _params, session, socket) do
    socket =
      socket
      |> AshAuthentication.Phoenix.LiveSession.assign_new_resources(session)
      |> assign_current_user_for_dev()
      |> assign_tz()
      |> assign_context()
      |> ErrorTrackerContext.set()
      |> attach_context_hook()

    {:cont, socket}
  end

  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      current_user = socket.assigns.current_user |> current_user_for_dev()
      current_scope = %Wik.Scope{actor: current_user, tenant: nil}

      socket =
        socket
        |> assign(:current_user, current_user)
        |> assign(current_scope: current_scope)
        |> assign_tz()
        |> assign_context()
        |> ErrorTrackerContext.set()
        |> attach_context_hook()

      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_superadmin_required, _params, _session, socket) do
    current_user = socket.assigns[:current_user] |> current_user_for_dev()

    cond do
      current_user == nil ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}

      current_user.role == :superadmin ->
        current_scope = %Wik.Scope{actor: current_user, tenant: nil}

        socket =
          socket
          |> assign(:current_user, current_user)
          |> assign(current_scope: current_scope)
          |> assign_tz()
          |> assign_context()
          |> ErrorTrackerContext.set()
          |> attach_context_hook()

        {:cont, socket}

      true ->
        socket = Phoenix.LiveView.put_flash(socket, :error, "Not found")
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    end
  end

  def on_mount(:live_scope_required, params, _session, socket) do
    current_user = socket.assigns[:current_user] |> current_user_for_dev()

    if current_user do
      group_name = params["group_name"]

      case group_name |> Accounts.get_group_by_name(actor: current_user) do
        {:ok, group} ->
          current_scope =
            %Wik.Scope{actor: current_user, tenant: group}
            |> assign_scope_avatar_url()

          socket =
            socket
            |> assign(:current_user, current_user)
            |> assign(current_scope: current_scope)
            |> assign_tz()
            |> assign_context()
            |> ErrorTrackerContext.set()
            |> attach_context_hook()

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
      socket =
        socket
        |> assign(:current_user, nil)
        |> assign_context()
        |> ErrorTrackerContext.set()

      {:cont, socket}
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
          :ok = WikWeb.Presence.subscribe_to_group(group_id)
          assign(socket, :presences, WikWeb.Presence.list_online_users_in_group(group_id))

        _ ->
          assign(socket, :presences, [])
      end

    {:cont, socket}
  end

  defp assign_current_user_for_dev(socket) do
    current_user = socket.assigns[:current_user] |> current_user_for_dev()
    assign(socket, :current_user, current_user)
  end

  defp assign_context(socket) do
    assign(socket, :context, Context.build(socket.assigns[:current_user]))
  end

  defp assign_tz(socket) do
    tz =
      case get_connect_params(socket) do
        %{"tz" => tz} when is_binary(tz) and tz != "" -> tz
        _ -> "Etc/UTC"
      end

    socket
    |> assign_new(:tz, fn -> tz end)
  end

  defp attach_context_hook(socket) do
    current_user = socket.assigns[:current_user]
    user_pub_sub_topic = current_user && GroupUserRelation.user_pub_sub_topic(current_user.id)

    if Phoenix.LiveView.connected?(socket) do
      :ok = Context.subscribe(current_user)
      :ok = subscribe_to_membership_updates(current_user)
    end

    attach_hook(socket, :context, :handle_info, fn
      {Context, :claimable_sources_changed}, socket ->
        socket =
          assign(socket, :context, Context.build(socket.assigns[:current_user]))

        {:halt, socket}

      %{topic: topic}, socket when topic == user_pub_sub_topic ->
        socket =
          socket
          |> assign_context()
          |> refresh_current_scope()
          |> ErrorTrackerContext.set()
          |> Phoenix.LiveView.put_flash(
            :info,
            "Your membership type changed. Some permissions may update on your next action."
          )

        {:halt, socket}

      _message, socket ->
        {:cont, socket}
    end)
  end

  defp subscribe_to_membership_updates(nil), do: :ok

  defp subscribe_to_membership_updates(%{id: user_id}) do
    WikWeb.Endpoint.subscribe(GroupUserRelation.user_pub_sub_topic(user_id))
  end

  defp current_user_for_dev(%{role: :superadmin} = user) do
    if dev_demote_superadmin?() do
      %{user | role: :user}
    else
      user
    end
  end

  defp current_user_for_dev(user), do: user

  defp dev_demote_superadmin? do
    @dev_routes? and System.get_env("WIK_DEV_DEMOTE_SUPERADMIN") == "true"
  end

  defp assign_scope_avatar_url(%{actor: actor, tenant: tenant} = scope) do
    case Access.get_user_group_avatar_url(actor, tenant) do
      {:ok, avatar_url} when is_binary(avatar_url) -> %{scope | avatar_url: avatar_url}
      {:ok, nil} -> scope
      {:error, _error} -> scope
    end
  end

  defp refresh_current_scope(%{assigns: %{current_scope: %{tenant: nil}}} = socket), do: socket
  defp refresh_current_scope(%{assigns: %{current_scope: nil}} = socket), do: socket

  defp refresh_current_scope(%{assigns: %{current_scope: %{tenant: tenant}}} = socket) do
    current_user = socket.assigns.current_user

    case Accounts.get_group_by_name(tenant.name, actor: current_user) do
      {:ok, group} ->
        current_scope =
          %Wik.Scope{actor: current_user, tenant: group}
          |> assign_scope_avatar_url()

        assign(socket, :current_scope, current_scope)

      _ ->
        socket
    end
  end
end
