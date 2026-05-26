defmodule WikWeb.Superadmin.InboxLive do
  use WikWeb, :live_view
  use Cinder.UrlSync

  alias AshPhoenix.Form
  alias Utils.Log
  alias Wik.Tickets.Ticket
  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:inbox_query, inbox_query())
     |> assign(:selected_ticket, nil)
     |> assign(:ticket_update_form, nil)}
  end

  @impl true
  def handle_params(params, uri, socket) do
    socket = Cinder.UrlSync.handle_params(params, uri, socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_ticket", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user

    case Ash.get(Ticket, id, actor: current_user, load: [:submitted_by]) do
      {:ok, ticket} ->
        {:noreply,
         socket
         |> assign(:selected_ticket, ticket)
         |> assign(:ticket_update_form, ticket |> init_ticket_update_form(current_user))}

      {:error, error} ->
        Log.scoped_error(socket.assigns.current_scope, error, "ticket lookup failed")
        {:noreply, put_flash(socket, :error, "Couldn't open ticket")}
    end
  end

  def handle_event("hide_ticket", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_ticket, nil)
     |> assign(:ticket_update_form, nil)}
  end

  def handle_event("ticket_update_validate", %{"form" => params}, socket) do
    {:noreply,
     assign(
       socket,
       :ticket_update_form,
       Form.validate(socket.assigns.ticket_update_form, params)
     )}
  end

  def handle_event("ticket_update_submit", %{"form" => params}, socket) do
    current_user = socket.assigns.current_user
    attrs = ticket_update_params(params)

    case Form.submit(socket.assigns.ticket_update_form, params: attrs) do
      {:ok, _ticket} ->
        case Ash.get(Ticket, socket.assigns.selected_ticket.id,
               actor: current_user,
               load: [:submitted_by]
             ) do
          {:ok, selected_ticket} ->
            {:noreply,
             socket
             |> assign(:selected_ticket, selected_ticket)
             |> assign(
               :ticket_update_form,
               init_ticket_update_form(selected_ticket, current_user)
             )
             |> put_flash(:info, "Ticket updated")}

          {:error, error} ->
            Log.scoped_error(socket.assigns.current_scope, error, "ticket reload failed")
            {:noreply, put_flash(socket, :error, "Ticket was updated, but couldn't be reloaded")}
        end

      {:error, error} ->
        Log.scoped_error(socket.assigns.current_scope, error, "ticket update failed")
        {:noreply, put_flash(socket, :error, "Couldn't update ticket")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app context={@context} flash={@flash} scope={@current_scope}>
      <Layouts.superadmin scope={@current_scope} view="inbox">
        <Cinder.collection
          actor={@current_user}
          click={fn ticket -> JS.push("show_ticket", value: %{id: ticket.id}) end}
          empty_message="No tickets yet."
          id="superadmin-inbox"
          page_size={[default: 25, options: [10, 25, 50, 100]]}
          query={@inbox_query}
          show_filters={:toggle}
          sort_mode="exclusive"
          theme={WikWeb.Cinder.Themes.Dense}
          url_state={@url_state}
        >
          <:col :let={ticket} field="type" label="Type" filter sort>
            <span
              class={[type_badge_class(ticket.type), "cursor-pointer"]}
              data-testid={"inbox-ticket-#{ticket.id}"}
            >
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

          <:col :let={ticket} field="submitted_by__email" label="Submitted by" filter search>
            <span class="whitespace-nowrap text-sm text-base-content/70">
              {user_label(ticket.submitted_by)}
            </span>
          </:col>

          <:col :let={ticket} field="app_path" label="App path" filter search>
            <span class="max-w-40 truncate font-mono text-xs text-base-content/55">
              {ticket.app_path}
            </span>
          </:col>

          <:col :let={ticket} field="inserted_at" label="Created" sort>
            <span class="whitespace-nowrap text-sm text-base-content/60">
              {format_timestamp(ticket.inserted_at)}
            </span>
          </:col>
        </Cinder.collection>

        <WikWeb.Components.Modal.render
          :if={@selected_ticket && @ticket_update_form}
          cancel="hide_ticket"
          cancel_testid="inbox-ticket-close"
          open?={true}
          testid="inbox-ticket-dialog"
        >
          <:title>
            {@selected_ticket.subject}
          </:title>

          <div class="space-y-5 text-sm">
            <div class="flex flex-wrap gap-2">
              <span class={type_badge_class(@selected_ticket.type)}>
                {ticket_type_label(@selected_ticket.type)}
              </span>
              <span class={status_badge_class(@selected_ticket.status)}>
                {ticket_status_label(@selected_ticket.status)}
              </span>
            </div>

            <dl class="grid gap-3 sm:grid-cols-2">
              <div>
                <dt class="text-xs uppercase tracking-wide text-base-content/45">Submitted by</dt>
                <dd>{user_label(@selected_ticket.submitted_by)}</dd>
              </div>
              <div>
                <dt class="text-xs uppercase tracking-wide text-base-content/45">App path</dt>
                <dd class="font-mono text-xs">{@selected_ticket.app_path}</dd>
              </div>
            </dl>

            <div class="rounded-[1.25rem] bg-base-200/70 p-4 leading-7 whitespace-pre-wrap">
              {@selected_ticket.body}
            </div>

            <.form
              for={@ticket_update_form}
              id="inbox-ticket-update-form"
              phx-change="ticket_update_validate"
              phx-submit="ticket_update_submit"
              class="space-y-4 rounded-[1.25rem] border border-base-300 bg-base-100 p-4"
            >
              <div class="grid gap-4 sm:grid-cols-2">
                <.input
                  field={@ticket_update_form[:status]}
                  type="select"
                  label="Status"
                  options={ticket_status_options()}
                />

                <div class="rounded-[1rem] border border-base-300 bg-base-200/50 px-4 py-3 text-xs leading-6 text-base-content/65">
                  Update the status and leave internal notes for your own follow-up.
                </div>
              </div>

              <.input
                field={@ticket_update_form[:admin_notes]}
                type="textarea"
                label="Internal notes"
                rows="6"
                placeholder="Notes visible only in the superadmin inbox."
              />

              <div class="flex justify-end">
                <.button variant="primary" type="submit">Save</.button>
              </div>
            </.form>
          </div>
        </WikWeb.Components.Modal.render>
      </Layouts.superadmin>
    </Layouts.app>
    """
  end

  defp inbox_query do
    Ticket
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.load([:submitted_by])
  end

  defp init_ticket_update_form(ticket, current_user) do
    ticket
    |> Form.for_update(:update, actor: current_user)
    |> to_form()
  end

  defp ticket_update_params(params) do
    handled_at =
      case params["status"] do
        "closed" -> DateTime.utc_now()
        _ -> nil
      end

    %{
      admin_notes: params["admin_notes"],
      handled_at: handled_at,
      status: params["status"]
    }
  end

  defp user_label(%{email: email}) when not is_nil(email) and email != "", do: to_string(email)
  defp user_label(%{id: id}), do: "user:#{id}"
  defp user_label(_user), do: "-"

  defp ticket_type_label(:feedback), do: "Feedback"
  defp ticket_type_label(:privacy_request), do: "Privacy"
  defp ticket_type_label(:moderation_report), do: "Moderation"

  defp ticket_status_label(:new), do: "New"
  defp ticket_status_label(:in_progress), do: "In progress"
  defp ticket_status_label(:closed), do: "Closed"

  defp ticket_status_options do
    [
      {"New", :new},
      {"In progress", :in_progress},
      {"Closed", :closed}
    ]
  end

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
