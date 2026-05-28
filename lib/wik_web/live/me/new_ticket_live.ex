defmodule WikWeb.Me.NewTicketLive do
  use WikWeb, :live_view

  alias AshPhoenix.Form
  alias Wik.Tickets.Ticket
  alias WikWeb.Components.UI

  on_mount {WikWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:current_path, nil)
     |> assign(:form, init_form(current_user))}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    current_path =
      uri
      |> URI.parse()
      |> Map.get(:path)
      |> Kernel.||(~p"/me/tickets/new")

    {:noreply, assign(socket, :current_path, current_path)}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, :form, Form.validate(socket.assigns.form, params))}
  end

  def handle_event("submit", %{"form" => params}, socket) do
    params = Map.put(params, "app_path", socket.assigns.current_path || ~p"/me/tickets/new")

    case Form.submit(socket.assigns.form, params: params) do
      {:ok, _ticket} ->
        {:noreply,
         socket
         |> put_flash(:info, "Ticket submitted")
         |> push_navigate(to: ~p"/me/tickets")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app context={@context} flash={@flash} scope={@current_scope}>
      <Layouts.me view="me/tickets">
        <div class="space-y-6">
          <section class="space-y-4">
            <.button navigate={~p"/me/tickets"} class="btn btn-sm">
              <.icon name="hero-arrow-left-micro" class="" /> Back to tickets
            </.button>

            <UI.page_title>New ticket</UI.page_title>

            <p class="text-sm text-base-content/70">
              Send feedback, report moderation issues, or request privacy-related help. For
              deletion and export requests, we may ask you to confirm your identity before acting.
            </p>
          </section>

          <section class="">
            <.form
              for={@form}
              id="new-ticket-form"
              phx-change="validate"
              phx-submit="submit"
              class="space-y-5"
            >
              <.input
                field={@form[:type]}
                type="select"
                label="Type"
                prompt="Choose a ticket type"
                options={ticket_type_options()}
              />

              <.input
                field={@form[:subject]}
                type="text"
                label="Subject"
                placeholder="Short summary"
              />

              <.input
                field={@form[:body]}
                type="textarea"
                label="Details"
                rows="8"
                placeholder="Describe the request, issue, or feedback in detail."
              />

              <div class="flex justify-end">
                <.button class="btn btn-sm btn-primary btn-soft" type="submit">
                  Submit ticket
                </.button>
              </div>
            </.form>
          </section>
        </div>
      </Layouts.me>
    </Layouts.app>
    """
  end

  defp init_form(current_user) do
    Ticket
    |> Form.for_create(:submit, actor: current_user)
    |> to_form()
  end

  defp ticket_type_options do
    [
      {"Feedback", :feedback},
      {"Privacy request", :privacy_request},
      {"Moderation report", :moderation_report}
    ]
  end
end
