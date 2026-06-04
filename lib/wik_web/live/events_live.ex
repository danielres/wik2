defmodule WikWeb.EventsLive do
  use WikWeb, :live_view

  alias Utils.Log
  alias Wik.Locations
  alias WikWeb.Components
  alias WikWeb.EventsLive
  alias WikWeb.EventsLive.EventForm
  alias WikWeb.EventsLive.Interest
  alias WikWeb.EventsLive.ModalView
  alias WikWeb.EventsLive.Params
  alias WikWeb.EventsLive.SubscriptionModal
  alias WikWeb.EventsLive.SubscriptionState
  alias WikWeb.EventsLive.TimelineState

  on_mount {WikWeb.LiveUserAuth, :live_scope_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(modal: nil)
     |> assign(presences: [])
     |> assign(subscriptions: SubscriptionState.empty())
     |> assign(timeline: TimelineState.empty())
     |> refresh_page_data()}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :modal_view, ModalView.build(assigns))

    ~H"""
    <Layouts.app
      context={@context}
      flash={@flash}
      tenant_context={@tenant_context}
      scope={@current_scope}
    >
      <Layouts.space presences={@presences} scope={@current_scope} view="events">
        <div class="space-y-6" data-testid="events-page">
          <div class="bg-base-200/70 rounded px-4 py-4 -mt-4">
            <EventsLive.Components.CalendarControls.render
              timeline={@timeline}
              subscriptions={@subscriptions}
              current_scope={@current_scope}
            />
          </div>

          <Components.Event.grouped_timeline
            current_scope={@current_scope}
            grouped_items={@timeline.grouped_items}
            load_more_path={@timeline.load_more_path}
            more_external_future?={@timeline.more_external_future?}
            show_external?={@timeline.show_external?}
            user_tz={@active_tz}
          />
        </div>

        <EventsLive.Components.Modal.render
          active_tz={@active_tz}
          current_scope={@current_scope}
          modal_view={@modal_view}
        />
      </Layouts.space>
    </Layouts.app>
    """
  end

  @impl true
  def handle_params(params, _url, socket) do
    route_params = Params.parse(params)

    socket =
      socket
      |> TimelineState.put_future_windows(route_params.future_windows)
      |> TimelineState.put_show_external(route_params.show_external?)
      |> refresh_page_data()

    publication =
      params["event"] &&
        Enum.find(
          socket.assigns.timeline.internal_publications,
          &(&1.event_id == params["event"])
        )

    socket =
      socket
      |> sync_modal_with_route(publication)

    {:noreply, socket}
  end

  @impl true
  def handle_event("event_create_start", _params, socket) do
    {:noreply, EventForm.open(socket)}
  end

  def handle_event("event_form_validate", params, socket) do
    {:noreply, EventForm.validate(socket, params)}
  end

  def handle_event("event_form_end_date_add", _params, socket) do
    {:noreply, EventForm.show_end_date(socket)}
  end

  def handle_event("event_form_end_date_remove", _params, socket) do
    {:noreply, EventForm.hide_end_date(socket)}
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

  def handle_event("event_form_submit", params, socket) do
    {:noreply, EventForm.submit(socket, params)}
  end

  def handle_event("event_form_cancel", _params, socket) do
    {:noreply, EventForm.cancel(socket)}
  end

  def handle_event("toggle_external", _params, socket) do
    current_scope = socket.assigns.current_scope
    timeline = socket.assigns.timeline

    params = Params.page_params(!timeline.show_external?, timeline.future_windows)

    {:noreply, push_patch(socket, to: ~p"/#{current_scope.tenant.slug}/events?#{params}")}
  end

  def handle_event("modal_close", _params, socket) do
    {:noreply, close_modal(socket)}
  end

  def handle_event("external_event_show", %{"id" => id}, socket) do
    external_event =
      Enum.find(socket.assigns.timeline.external_items, &(&1.id == id))

    {:noreply, assign(socket, :modal, {:external_event, external_event})}
  end

  def handle_event("event_interest_start", %{"source_type" => "internal", "id" => id}, socket) do
    {:noreply, Interest.open_internal(socket, id)}
  end

  def handle_event("event_interest_start", %{"source_type" => "external", "id" => id}, socket) do
    {:noreply, Interest.open_external(socket, id)}
  end

  def handle_event("event_interest_cancel", _params, socket) do
    {:noreply, Interest.cancel(socket)}
  end

  def handle_event("event_interest_submit", params, socket) do
    {:noreply, Interest.submit(socket, params)}
  end

  def handle_event("external_calendar_subscription_start", _params, socket) do
    {:noreply, SubscriptionModal.new(socket)}
  end

  def handle_event("external_calendar_subscription_show", %{"id" => id}, socket) do
    {:noreply, SubscriptionModal.show(socket, id)}
  end

  def handle_event(
        "external_calendar_subscription_submit",
        params,
        socket
      ) do
    {:noreply, SubscriptionModal.submit(socket, params)}
  end

  def handle_event("external_calendar_subscription_remove", %{"id" => id}, socket) do
    {:noreply, SubscriptionModal.remove(socket, id)}
  end

  def handle_event("external_calendar_subscription_refresh", %{"id" => id}, socket) do
    {:noreply, SubscriptionModal.refresh(socket, id)}
  end

  def handle_event(
        "external_calendar_subscription_name_submit",
        params,
        socket
      ) do
    {:noreply, SubscriptionModal.submit_name(socket, params)}
  end

  @impl true
  def handle_info({:event_details, :saved}, socket) do
    current_scope = socket.assigns.current_scope
    timeline = socket.assigns.timeline
    page_params = Params.page_params(timeline.show_external?, timeline.future_windows)

    socket =
      socket
      |> assign(:modal, nil)
      |> refresh_page_data()
      |> push_patch(to: ~p"/#{current_scope.tenant.slug}/events?#{page_params}")

    {:noreply, socket}
  end

  def handle_info({:event_details, :relay_completed}, socket) do
    {:noreply, put_flash(socket, :info, "Event relayed")}
  end

  def refresh_page_data(socket) do
    TimelineState.refresh_page_data(socket)
  end

  defp sync_modal_with_route(socket, nil) do
    if route_event_modal?(socket.assigns.modal) do
      assign(socket, :modal, nil)
    else
      socket
    end
  end

  defp sync_modal_with_route(socket, publication) do
    assign(socket, :modal, {:internal_event, publication})
  end

  defp close_modal(socket) do
    current_scope = socket.assigns.current_scope
    timeline = socket.assigns.timeline

    case socket.assigns.modal do
      {:internal_event, _publication} ->
        params =
          Params.page_params(timeline.show_external?, timeline.future_windows)

        socket
        |> assign(:modal, nil)
        |> push_patch(to: ~p"/#{current_scope.tenant.slug}/events?#{params}")

      _ ->
        assign(socket, :modal, nil)
    end
  end

  defp route_event_modal?({:internal_event, _publication}), do: true
  defp route_event_modal?({:external_event, _item}), do: true
  defp route_event_modal?(_modal), do: false
end
