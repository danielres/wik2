defmodule WikWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """
  @dev_routes? Application.compile_env(:wik, :dev_routes, false)

  alias Wik.Accounts
  alias Wik.Accounts.Membership
  alias Wik.Events.ExternalCalendar
  alias WikWeb.Context
  alias WikWeb.ErrorTrackerContext
  alias WikWeb.TenantContext

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
      |> assign_active_tz()
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
        |> assign(:tenant_context, nil)
        |> assign_active_tz()
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
          |> assign(:tenant_context, nil)
          |> assign_active_tz()
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
      space_slug = params["space_slug"]

      case space_slug |> Accounts.get_space_by_slug(actor: current_user) do
        {:ok, space} ->
          current_scope = %Wik.Scope{actor: current_user, tenant: space}
          tenant_context = TenantContext.build(current_user, space)

          socket =
            socket
            |> assign(:current_user, current_user)
            |> assign(current_scope: current_scope)
            |> assign(:tenant_context, tenant_context)
            |> assign_active_tz()
            |> assign_context()
            |> ErrorTrackerContext.set()
            |> attach_context_hook()

          if Phoenix.LiveView.connected?(socket) and ExternalCalendar.stale_refresh_enabled?() do
            ExternalCalendar.refresh_stale_space_subscriptions(current_scope)
          end

          {:cont, socket}

        _ ->
          socket = Phoenix.LiveView.put_flash(socket, :error, ~s(Space "#{space_slug}" not found))
          {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
      end
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:admin_required, _params, _session, socket) do
    if TenantContext.space_admin?(socket.assigns[:current_scope], socket.assigns[:tenant_context]) do
      {:cont, socket}
    else
      socket = Phoenix.LiveView.put_flash(socket, :error, "Not found")
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      socket =
        socket
        |> assign(:current_user, nil)
        |> assign(:tenant_context, nil)
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
        {true, %{tenant: %{id: space_id}}} ->
          :ok = WikWeb.Presence.subscribe_to_space(space_id)
          assign(socket, :presences, WikWeb.Presence.list_online_users_in_space(space_id))

        _ ->
          assign(socket, :presences, [])
      end

    {:cont, socket}
  end

  def on_mount(:subscribe_space_memberships, _params, _session, socket) do
    socket = assign(socket, :subscribe_space_memberships?, true)

    if Phoenix.LiveView.connected?(socket) do
      :ok = subscribe_to_space_membership_updates(socket)
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

  defp assign_active_tz(socket) do
    current_user = socket.assigns[:current_user]
    browser_detected_tz = browser_detected_tz(socket)

    socket
    |> assign(:browser_detected_tz, browser_detected_tz)
    |> assign(:active_tz, active_tz(current_user, browser_detected_tz))
  end

  def active_tz(current_user, browser_detected_tz) do
    case current_user do
      %{tz: tz} when is_binary(tz) and tz != "" ->
        if Utils.Tz.valid?(tz), do: tz, else: browser_detected_tz

      _ ->
        browser_detected_tz
    end
  end

  defp browser_detected_tz(socket) do
    case get_connect_params(socket) do
      %{"tz" => tz} when is_binary(tz) and tz != "" ->
        if Utils.Tz.valid?(tz), do: tz, else: "Etc/UTC"

      _ ->
        "Etc/UTC"
    end
  end

  defp attach_context_hook(socket) do
    current_user = socket.assigns[:current_user]
    user_pub_sub_topic = current_user && Membership.user_pub_sub_topic(current_user.id)
    space_membership_pub_sub_topic = current_space_membership_pub_sub_topic(socket)

    if Phoenix.LiveView.connected?(socket) do
      :ok = Context.subscribe(current_user)
      :ok = subscribe_to_membership_updates(current_user)
    end

    socket
    |> attach_hook(:context, :handle_info, fn
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

        {:halt, socket}

      %{topic: topic}, socket when topic == space_membership_pub_sub_topic ->
        socket =
          socket
          |> refresh_current_scope()
          |> ErrorTrackerContext.set()

        {:cont, socket}

      _message, socket ->
        {:cont, socket}
    end)
    |> attach_membership_username_hook()
  end

  defp attach_membership_username_hook(socket) do
    attach_hook(socket, :membership_username, :handle_event, fn
      "membership_username_validate", %{"form" => params}, socket ->
        params = slugify_username_params(params)

        form =
          socket.assigns.tenant_context.membership_username_form
          |> AshPhoenix.Form.validate(params)
          |> to_form()

        tenant_context =
          socket.assigns.tenant_context
          |> Map.put(:membership_username_form, form)

        {:halt, assign(socket, :tenant_context, tenant_context)}

      "membership_username_submit", %{"form" => params}, socket ->
        params = slugify_username_params(params)

        case AshPhoenix.Form.submit(socket.assigns.tenant_context.membership_username_form,
               params: params
             ) do
          {:ok, _membership} ->
            {:halt, refresh_current_scope(socket)}

          {:error, form} ->
            tenant_context =
              socket.assigns.tenant_context
              |> Map.put(:membership_username_form, to_form(form))

            {:halt, assign(socket, :tenant_context, tenant_context)}
        end

      _event, _params, socket ->
        {:cont, socket}
    end)
  end

  defp slugify_username_params(%{"username" => username} = params) do
    Map.put(params, "username", Utils.Slugify.generate(username))
  end

  defp slugify_username_params(params), do: params

  defp subscribe_to_membership_updates(nil), do: :ok

  defp subscribe_to_membership_updates(%{id: user_id}) do
    WikWeb.Endpoint.subscribe(Membership.user_pub_sub_topic(user_id))
  end

  defp subscribe_to_space_membership_updates(%{
         assigns: %{current_scope: %{tenant: %{id: space_id}}}
       }) do
    WikWeb.Endpoint.subscribe(Membership.space_pub_sub_topic(space_id))
  end

  defp subscribe_to_space_membership_updates(_socket), do: :ok

  defp current_space_membership_pub_sub_topic(%{
         assigns: %{
           subscribe_space_memberships?: true,
           current_scope: %{tenant: %{id: space_id}}
         }
       }) do
    Membership.space_pub_sub_topic(space_id)
  end

  defp current_space_membership_pub_sub_topic(_socket), do: nil

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

  defp refresh_current_scope(%{assigns: %{current_scope: %{tenant: nil}}} = socket), do: socket
  defp refresh_current_scope(%{assigns: %{current_scope: nil}} = socket), do: socket

  defp refresh_current_scope(%{assigns: %{current_scope: %{tenant: tenant}}} = socket) do
    current_user = socket.assigns.current_user

    case Accounts.get_space_by_slug(tenant.slug, actor: current_user) do
      {:ok, space} ->
        current_scope = %Wik.Scope{actor: current_user, tenant: space}
        tenant_context = TenantContext.build(current_user, space)

        socket
        |> assign(:current_scope, current_scope)
        |> assign(:tenant_context, tenant_context)

      _ ->
        socket
    end
  end
end
