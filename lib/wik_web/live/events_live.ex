defmodule WikWeb.EventsLive do
  use WikWeb, :live_view

  alias Ash.Query
  alias AshPhoenix.Form
  alias Utils.Log
  alias Wik.Events.Event
  alias Wik.Events.EventPublication
  alias Wik.Locations
  alias WikWeb.Components
  alias WikWeb.Components.Event.Details
  alias WikWeb.Components.Event.FormState
  alias WikWeb.Components.UI

  on_mount {WikWeb.LiveUserAuth, :live_scope_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(event_form: nil)
     |> assign(event_publications: [])
     |> assign(presences: [])
     |> assign(selected_publication: nil)
     |> refresh_timeline()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app context={@context} flash={@flash} scope={@current_scope}>
      <Layouts.group presences={@presences} scope={@current_scope} view="events">
        <div class="space-y-6" data-testid="events-page">
          <div class="flex flex-wrap items-start gap-4">
            <h1 class="text-2xl font-[100] flex-grow">Events</h1>

            <Components.CalendarFeed.group_subscribe_button scope={@current_scope} />

            <UI.button_plus
              :if={Ash.can?({Event, :create}, @current_scope)}
              data-testid="events-create-button"
              phx-click="event_create_start"
            />
          </div>

          <Components.Event.list
            current_scope={@current_scope}
            event_publications={@event_publications}
            user_tz={@active_tz}
          />
        </div>

        <Components.Modal.render
          cancel="event_modal_close"
          cancel_testid="event-modal-close"
          open?={@event_form != nil or @selected_publication != nil}
          testid="event-modal-dialog"
        >
          <:title :if={@event_form != nil}>
            <div class="flex items-center justify-between gap-3">
              <h2 class="text-lg font-medium">
                {if @event_form.source.type == :create, do: "Create event", else: "Edit event"}
              </h2>

              <span class="badge bg-base-300">{@active_tz}</span>
            </div>
          </:title>

          <.live_component
            :if={@selected_publication != nil}
            module={Details}
            id={"event-details-#{@selected_publication.id}"}
            current_scope={@current_scope}
            publication={@selected_publication}
            user_tz={@active_tz}
          />

          <Components.Event.event_form
            :if={@event_form != nil}
            form={@event_form}
            user_tz={@active_tz}
          />
        </Components.Modal.render>
      </Layouts.group>
    </Layouts.app>
    """
  end

  @impl true
  def handle_params(params, _url, socket) do
    event_publications = socket.assigns.event_publications

    publication =
      params["event"] &&
        Enum.find(event_publications, &(&1.id == params["event"]))

    socket =
      case publication do
        nil ->
          socket
          |> assign(:event_form, nil)
          |> assign(:selected_publication, nil)

        publication ->
          socket
          |> assign(:event_form, nil)
          |> assign(:selected_publication, publication)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("event_create_start", _params, socket) do
    current_scope = socket.assigns.current_scope
    active_tz = socket.assigns.active_tz

    socket =
      socket
      |> assign(:selected_publication, nil)
      |> assign(:event_form, FormState.new(current_scope, active_tz))

    {:noreply, socket}
  end

  def handle_event("event_form_validate", %{"form" => params}, socket) do
    event_form = socket.assigns.event_form

    socket =
      socket
      |> assign(:event_form, FormState.validate(event_form, params))

    {:noreply, socket}
  end

  def handle_event("location_search", %{"q" => query}, socket) do
    scope = socket.assigns.current_scope

    case Locations.search(query) do
      {:ok, options} ->
        {:reply, %{options: options}, socket}

      {:error, error} ->
        Log.scoped_error(scope, error, "location_search failed")
        {:reply, %{options: []}, socket}
    end
  end

  def handle_event("event_form_submit", %{"form" => params}, socket) do
    current_scope = socket.assigns.current_scope

    socket =
      case Form.submit(socket.assigns.event_form,
             params: params,
             action_opts: [scope: current_scope]
           ) do
        {:ok, _event} ->
          socket
          |> assign(:event_form, nil)
          |> assign(:selected_publication, nil)
          |> refresh_timeline()
          |> push_patch(to: ~p"/#{current_scope.tenant.name}/events")

        {:error, form} ->
          assign(socket, :event_form, form)
      end

    {:noreply, socket}
  end

  def handle_event("event_form_cancel", _params, socket) do
    {:noreply, assign(socket, :event_form, nil)}
  end

  def handle_event("event_modal_close", _params, socket) do
    current_scope = socket.assigns.current_scope

    socket =
      socket
      |> assign(:event_form, nil)
      |> assign(:selected_publication, nil)
      |> push_patch(to: ~p"/#{current_scope.tenant.name}/events")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:event_details, :saved}, socket) do
    current_scope = socket.assigns.current_scope

    socket =
      socket
      |> assign(:selected_publication, nil)
      |> refresh_timeline()
      |> push_patch(to: ~p"/#{current_scope.tenant.name}/events")

    {:noreply, socket}
  end

  def handle_info({:event_details, :relay_completed}, socket) do
    {:noreply, put_flash(socket, :info, "Event relayed")}
  end

  defp refresh_timeline(socket) do
    scope = socket.assigns.current_scope

    publications_query =
      EventPublication
      |> Query.sort([{"event.starts_at", :asc}, {:inserted_at, :asc}])
      |> Query.load([:published_by, event: [:author, :group]])

    with {:ok, group} <-
           Ash.load(
             scope.tenant,
             [event_publications: publications_query],
             scope: scope
           ) do
      socket
      |> assign(:event_publications, group.event_publications)
    else
      {:error, error} ->
        Log.scoped_error(scope, error, "refresh_timeline failed")

        socket
        |> assign(:event_publications, [])
        |> put_flash(:error, "Could not load events")
    end
  end
end
