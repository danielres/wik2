defmodule WikWeb.Me.SettingsLive do
  use WikWeb, :live_view

  alias AshPhoenix.Form
  alias Utils.Log
  alias WikWeb.Components.Modal
  alias WikWeb.LiveUserAuth
  alias WikWeb.Me

  on_mount {WikWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(form_update_user_tz: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app context={@context} flash={@flash} scope={@current_scope}>
      <Layouts.me view="me">
        <div class="card bg-base-200 max-w-sm">
          <div class="card-body">
            <div class="font-bold">Your timezone</div>
            <span class={["tooltip tooltip-bottom"]}>
              <%= if Ash.can?({@current_user, :update_tz}, @current_scope) do %>
                <button
                  class={["link decoration-dashed"]}
                  data-testid="me-timezone-button"
                  phx-click="update_user_tz_start"
                  type="button"
                >
                  {@active_tz}
                </button>
              <% else %>
                <span>
                  {@active_tz}
                </span>
              <% end %>

              <div class="tooltip-content max-w-[12rem] text-xs">
                {if @current_user.tz,
                  do: "Custom timezone set by you",
                  else: "Auto-detected from your browser settings"}
              </div>
            </span>
          </div>
        </div>

        <Modal.render
          cancel="update_user_tz_cancel"
          cancel_testid="update-user-tz-cancel"
          open?={@form_update_user_tz != nil}
          testid="update-user-tz-dialog"
        >
          <Me.Components.form_tz
            :if={Ash.can?({@current_user, :update_tz}, @current_scope)}
            saved_tz={@current_user.tz}
            form={@form_update_user_tz}
            active_tz={@active_tz}
          />
        </Modal.render>
      </Layouts.me>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("update_user_tz_start", _params, socket) do
    current_scope = socket.assigns.current_scope
    current_user = socket.assigns.current_user

    socket =
      socket
      |> assign(
        :form_update_user_tz,
        current_user |> Form.for_update(:update_tz, scope: current_scope) |> to_form()
      )

    {:noreply, socket}
  end

  def handle_event("update_user_tz_validate", %{"form" => params}, socket) do
    form_update_user_tz = socket.assigns.form_update_user_tz

    socket =
      socket
      |> assign(:form_update_user_tz, Form.validate(form_update_user_tz, params))

    {:noreply, socket}
  end

  def handle_event("update_user_tz_submit", %{"form" => params}, socket) do
    socket =
      case Form.submit(socket.assigns.form_update_user_tz, params: params) do
        {:ok, current_user} ->
          current_scope = %{socket.assigns.current_scope | actor: current_user}

          socket
          |> assign(:current_scope, current_scope)
          |> assign(:current_user, current_user)
          |> assign(
            :active_tz,
            LiveUserAuth.active_tz(current_user, socket.assigns.browser_detected_tz)
          )
          |> assign(:form_update_user_tz, nil)

        {:error, form_update_user_tz} ->
          assign(socket, :form_update_user_tz, form_update_user_tz)
      end

    {:noreply, socket}
  end

  def handle_event("update_user_tz_auto_detect", _params, socket) do
    current_scope = socket.assigns.current_scope
    current_user = socket.assigns.current_user

    socket =
      case Ash.update(current_user, %{tz: nil}, action: :update_tz, scope: current_scope) do
        {:ok, current_user} ->
          current_scope = %{current_scope | actor: current_user}

          socket
          |> assign(:current_scope, current_scope)
          |> assign(:current_user, current_user)
          |> assign(:active_tz, socket.assigns.browser_detected_tz)
          |> assign(:form_update_user_tz, nil)

        {:error, error} ->
          Log.scoped_error(current_scope, error, "resetting user timezone failed")
          put_flash(socket, :error, "Couldn't reset timezone")
      end

    {:noreply, socket}
  end

  def handle_event("update_user_tz_cancel", _params, socket) do
    {:noreply, assign(socket, :form_update_user_tz, nil)}
  end
end
