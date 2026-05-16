defmodule WikWeb.Me.TicketsLive do
  use WikWeb, :live_view
  use Cinder.UrlSync

  alias Utils.Log
  alias Wik.Tickets
  alias WikWeb.Components.UI

  on_mount {WikWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:selected_ticket, nil)
     |> assign(:tickets_query, Tickets.tickets_query_for_user(socket.assigns.current_user))}
  end

  @impl true
  def handle_params(params, uri, socket) do
    socket = Cinder.UrlSync.handle_params(params, uri, socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_ticket", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user

    case Tickets.get_ticket(id, actor: current_user) do
      {:ok, ticket} ->
        {:noreply, assign(socket, :selected_ticket, ticket)}

      {:error, error} ->
        Log.scoped_error(socket.assigns.current_scope, error, "ticket lookup failed")
        {:noreply, put_flash(socket, :error, "Couldn't open ticket")}
    end
  end

  def handle_event("hide_ticket", _params, socket) do
    {:noreply, assign(socket, :selected_ticket, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app context={@context} flash={@flash} scope={@current_scope}>
      <Layouts.me view="me/tickets">
        <div class="space-y-6">
          <section class="space-y-4">
            <UI.page_title>My tickets</UI.page_title>

            <p class="text-sm text-base-content/70">
              Use tickets for feedback, privacy requests, and moderation reports. Requests are reviewed manually.
            </p>

            <.button navigate={~p"/me/tickets/new"} class="btn btn-sm btn-primary">
              New ticket
            </.button>
          </section>

          <section>
            <Cinder.collection
              actor={@current_user}
              click={fn ticket -> JS.push("show_ticket", value: %{id: ticket.id}) end}
              empty_message="No tickets yet."
              id="my-tickets"
              page_size={[default: 25, options: [10, 25, 50, 100]]}
              query={@tickets_query}
              show_filters={false}
              sort_mode="exclusive"
              theme={WikWeb.Cinder.Themes.Dense}
              url_state={@url_state}
            >
              <:col :let={ticket} field="type" label="Type" filter sort>
                <span class={type_badge_class(ticket.type)} data-testid={"my-ticket-#{ticket.id}"}>
                  {ticket_type_label(ticket.type)}
                </span>
              </:col>

              <:col :let={ticket} field="subject" label="Subject" filter search>
                <div class="font-medium">{ticket.subject}</div>
                <div class="mt-1 line-clamp-1 text-xs text-base-content/55">{ticket.body}</div>
              </:col>

              <:col :let={ticket} field="status" label="Status" filter sort>
                <span class={status_badge_class(ticket.status)}>
                  {ticket_status_label(ticket.status)}
                </span>
              </:col>

              <:col :let={ticket} field="app_path" label="App path" filter search>
                <span class="max-w-40 truncate font-mono text-xs text-base-content/55">
                  {ticket.app_path}
                </span>
              </:col>

              <:col :let={ticket} field="inserted_at" label="Submitted" sort>
                <span class="whitespace-nowrap text-sm text-base-content/60">
                  {format_timestamp(ticket.inserted_at)}
                </span>
              </:col>
            </Cinder.collection>
          </section>

          <WikWeb.Components.Modal.render
            :if={@selected_ticket}
            cancel="hide_ticket"
            cancel_testid="my-ticket-close"
            open?={true}
            testid="my-ticket-dialog"
          >
            <:title>
              {@selected_ticket.subject}
            </:title>

            <.ticket ticket={@selected_ticket} />
          </WikWeb.Components.Modal.render>
        </div>
      </Layouts.me>
    </Layouts.app>
    """
  end

  attr :ticket, :map, required: true

  def ticket(assigns) do
    ~H"""
    <div class="space-y-4 text-sm">
      <div class="flex flex-wrap gap-2">
        <span class={type_badge_class(@ticket.type)}>
          {ticket_type_label(@ticket.type)}
        </span>

        <span class={status_badge_class(@ticket.status)}>
          {ticket_status_label(@ticket.status)}
        </span>
      </div>

      <dl class="grid gap-3 sm:grid-cols-2">
        <div>
          <dt class="text-xs uppercase tracking-wide text-base-content/45">Submitted</dt>
          <dd>{format_timestamp(@ticket.inserted_at)}</dd>
        </div>
        <div>
          <dt class="text-xs uppercase tracking-wide text-base-content/45">App path</dt>
          <dd class="font-mono text-xs">{@ticket.app_path}</dd>
        </div>
      </dl>

      <div class="rounded bg-base-200/70 p-4 whitespace-pre-wrap">{@ticket.body}</div>
    </div>
    """
  end

  defp ticket_type_label(:feedback), do: "Feedback"
  defp ticket_type_label(:privacy_request), do: "Privacy"
  defp ticket_type_label(:moderation_report), do: "Moderation"

  defp ticket_status_label(:new), do: "New"
  defp ticket_status_label(:in_progress), do: "In progress"
  defp ticket_status_label(:closed), do: "Closed"

  defp type_badge_class(:feedback), do: "badge badge-sm badge-info"
  defp type_badge_class(:privacy_request), do: "badge badge-sm badge-warning"
  defp type_badge_class(:moderation_report), do: "badge badge-sm badge-error"

  defp status_badge_class(:new), do: "badge badge-sm bg-base-200 text-base-content/70"
  defp status_badge_class(:in_progress), do: "badge badge-sm badge-primary"
  defp status_badge_class(:closed), do: "badge badge-sm badge-success"

  defp format_timestamp(timestamp) do
    Calendar.strftime(timestamp, "%Y-%m-%d %H:%M UTC")
  end
end
