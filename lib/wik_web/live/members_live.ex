defmodule WikWeb.MembersLive do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers

  alias AshPhoenix.Form
  alias Wik.Accounts.Membership
  alias Wik.Blocks
  alias WikWeb.Components
  alias WikWeb.Components.Modal
  alias WikWeb.Components.UI
  alias WikWeb.SpaceLive.MembershipTypeSelector
  alias WikWeb.SpaceLive.NewOwnerSelector

  on_mount {WikWeb.LiveUserAuth, :live_scope_required}
  on_mount {WikWeb.LiveUserAuth, :subscribe_presence}

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    space = socket.assigns.current_scope.tenant |> load_space(scope)

    if connected?(socket) do
      :ok = WikWeb.Endpoint.subscribe(Membership.space_pub_sub_topic(space.id))
    end

    current_membership = socket.assigns.tenant_context[:current_membership]
    is_owner = current_membership && current_membership.type == :owner
    is_superadmin = scope.actor.role == :superadmin

    editable? = is_owner || is_superadmin

    socket =
      socket
      |> assign(editing?: false)
      |> assign(editable?: editable?)
      |> assign(space: space)
      |> assign(selected_membership: nil)
      |> assign(membership_type_form: nil)
      |> assign(transfer_ownership_form: nil)

    {:ok, socket}
  end

  defp init_form(space, scope) do
    space |> Form.for_update(:update, scope: scope) |> to_form()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      context={@context}
      flash={@flash}
      tenant_context={@tenant_context}
      scope={@current_scope}
    >
      <Layouts.space presences={@presences} scope={@current_scope} view="members">
        <:actions :if={@editable?}>
          <%= if @editing? do %>
            <UI.button_ok phx-click="toggle_edit_mode" />
          <% else %>
            <UI.button_edit phx-click="toggle_edit_mode" />
          <% end %>
        </:actions>

        <Modal.render
          cancel="membership_type_change_cancel"
          cancel_testid="membership-type-change-cancel"
          open?={@membership_type_form != nil}
          testid="membership-type-change-dialog"
        >
          <MembershipTypeSelector.render
            :if={@membership_type_form != nil and @selected_membership != nil}
            event_submit="membership_type_change_submit"
            form={@membership_type_form}
            membership={@selected_membership}
            type_options={Membership.updatable_types()}
          />
        </Modal.render>

        <Modal.render
          cancel="transfer_ownership_cancel"
          cancel_testid="transfer-ownership-cancel"
          open?={@transfer_ownership_form != nil}
          testid="transfer-ownership-dialog"
        >
          <NewOwnerSelector.render
            event_transfer_ownership="transfer_ownership"
            memberships={@space.memberships}
          />
        </Modal.render>
        <Components.Block.Types.Members.render
          event_membership_type_change_start="membership_type_change_start"
          event_transfer_ownership_start="transfer_ownership_start"
          scope={@current_scope}
          block={%{id: "members-block"}}
          actions?={@editable? and @editing?}
        />
      </Layouts.space>
    </Layouts.app>
    """
  end

  @impl true
  def handle_params(_params, url, socket) do
    {:noreply, WikWeb.Presence.track_in_liveview(socket, url)}
  end

  @impl true
  def handle_info(%{topic: topic}, socket) do
    space = socket.assigns.space

    if topic == Membership.space_pub_sub_topic(space.id) do
      {:noreply, refresh_space_memberships(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("membership_type_change_start", params, socket) do
    space = socket.assigns.space
    scope = socket.assigns.current_scope
    membership_id = params["membership_id"]

    case Enum.find(space.memberships, &(&1.id == membership_id and &1.type != :owner)) do
      nil ->
        {:noreply, socket}

      membership ->
        form = membership |> Form.for_update(:update_membership_type, scope: scope) |> to_form()

        {:noreply,
         socket
         |> assign(membership_type_form: form)
         |> assign(selected_membership: membership)}
    end
  end

  def handle_event("membership_type_change_cancel", _params, socket) do
    {:noreply,
     socket
     |> assign(membership_type_form: nil)
     |> assign(selected_membership: nil)}
  end

  def handle_event("membership_type_change_submit", %{"form" => params}, socket) do
    form = socket.assigns.membership_type_form

    case Form.submit(form, params: params) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> assign(membership_type_form: nil)
         |> assign(selected_membership: nil)}

      {:error, form} ->
        {:noreply, socket |> assign(membership_type_form: form)}
    end
  end

  def handle_event("transfer_ownership_start", params, socket) do
    space = socket.assigns.space
    scope = socket.assigns.current_scope
    membership_id = params["membership_id"]

    case Enum.find(space.memberships, &(&1.id == membership_id)) do
      nil ->
        {:noreply, socket}

      membership ->
        form = membership |> Form.for_update(:transfer_ownership, scope: scope) |> to_form()
        socket = socket |> assign(transfer_ownership_form: form)
        {:noreply, socket}
    end
  end

  def handle_event("transfer_ownership_cancel", _params, socket) do
    socket = socket |> assign(transfer_ownership_form: nil)
    {:noreply, socket}
  end

  def handle_event(
        "transfer_ownership",
        %{"target_membership_id" => target_membership_id},
        socket
      ) do
    form = socket.assigns.transfer_ownership_form

    case Form.submit(form, params: %{target_membership_id: target_membership_id}) do
      {:ok, _membership} ->
        {:noreply, socket |> assign(transfer_ownership_form: nil)}

      {:error, form} ->
        {:noreply, socket |> assign(transfer_ownership_form: form)}
    end
  end

  defp load_space(space, scope) do
    Ash.load!(space, [memberships: [:user]], scope: scope)
  end

  defp refresh_space_memberships(socket) do
    scope = socket.assigns.current_scope
    space = socket.assigns.space |> load_space(scope)

    socket
    |> assign(space: space)
    |> assign_membership_type_form(space.memberships)
  end

  defp assign_membership_type_form(socket, memberships) do
    case socket.assigns.selected_membership do
      nil ->
        socket

      membership ->
        membership = Enum.find(memberships, &(&1.id == membership.id and &1.type != :owner))

        case membership do
          nil ->
            socket
            |> assign(selected_membership: nil)
            |> assign(membership_type_form: nil)

          membership ->
            socket
            |> assign(selected_membership: membership)
            |> assign(
              membership_type_form:
                membership
                |> Form.for_update(:update_membership_type, scope: socket.assigns.current_scope)
                |> to_form()
            )
        end
    end
  end

  @impl true
  def handle_event("toggle_edit_mode", _params, socket) do
    socket = socket |> assign(editing?: !socket.assigns.editing?)
    {:noreply, socket}
  end
end
