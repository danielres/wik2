defmodule WikWeb.EventsLive do
  use WikWeb, :live_view

  alias Utils.Log
  alias Wik.Locations
  alias WikWeb.Components
  alias WikWeb.EventsLive
  alias WikWeb.EventsLive.Components.EventForm
  alias WikWeb.EventsLive.Components.InterestForm
  alias WikWeb.EventsLive.Components.SubscriptionDetails
  alias WikWeb.EventsLive.Components.SubscriptionForm
  alias WikWeb.EventsLive.Params
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
    assigns = assign(assigns, :modal_title, modal_title(assigns.modal, assigns.subscriptions))

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
          >
            <:meta :let={item}>
              <div
                :if={item.source_type == :external and item.calendar_name not in [nil, ""]}
                class="truncate text-xs opacity-60 flex items-center gap-1"
                data-testid={"external-event-calendar-name-#{item.id}"}
              >
                <.icon name="hero-calendar-days-micro" class="opacity-60" />
                {item.calendar_name}
              </div>
            </:meta>
          </Components.Event.grouped_timeline>
        </div>
      </Layouts.space>
    </Layouts.app>

    <Components.Modal.render
      cancel="modal_close"
      cancel_testid="events-modal-close"
      open?={@modal != nil}
    >
      <:title>
        {@modal_title}
      </:title>

      <%= case @modal do %>
        <% {:internal_event, publication} -> %>
          <.live_component
            module={Components.Event.Details}
            id={"event-details-#{publication.id}"}
            current_scope={@current_scope}
            publication={publication}
            user_tz={@active_tz}
          />
        <% {:external_event, item} -> %>
          <Components.Event.ExternalDetails.render
            current_membership={@tenant_context && @tenant_context.current_membership}
            current_scope={@current_scope}
            item={item}
            user_tz={@active_tz}
          />
        <% :event_form -> %>
          <.live_component
            module={EventForm}
            id="events-event-form"
            current_scope={@current_scope}
            user_tz={@active_tz}
          />
        <% {:interest, :internal, publication_id} -> %>
          <% publication =
            Enum.find(@timeline.internal_publications, &(&1.id == publication_id)) %>
          <% item =
            Enum.find(@timeline.internal_items, &(&1.publication.id == publication_id)) %>

          <.live_component
            module={InterestForm}
            id="events-interest-form"
            current_member_participation={item && item.current_member_participation}
            current_scope={@current_scope}
            external_event={nil}
            publication={publication}
            source_id={publication_id}
            source_type={:internal}
          />
        <% {:interest, :external, external_event_id} -> %>
          <% item =
            Enum.find(@timeline.external_items, &(&1.event.id == external_event_id)) %>

          <.live_component
            module={InterestForm}
            id="events-interest-form"
            current_member_participation={item && item.current_member_participation}
            current_scope={@current_scope}
            external_event={item && item.event}
            publication={nil}
            source_id={external_event_id}
            source_type={:external}
          />
        <% {:subscription, :new} -> %>
          <.live_component
            module={SubscriptionForm}
            id="events-subscription-form-content"
            current_scope={@current_scope}
          />
        <% {:subscription, {:show, subscription_id}} -> %>
          <% subscription = SubscriptionState.find(@subscriptions, subscription_id) %>
          <% metadata = SubscriptionState.metadata(@subscriptions, subscription) %>

          <.live_component
            module={SubscriptionDetails}
            id={"events-subscription-detail-#{subscription_id}"}
            current_scope={@current_scope}
            current_membership={@tenant_context && @tenant_context.current_membership}
            metadata={metadata}
            subscription={subscription}
          />
        <% _ -> %>
      <% end %>
    </Components.Modal.render>
    """
  end

  # handle_params ==============================================================

  @impl true
  def handle_params(params, _url, socket) do
    route_params = Params.parse(params)

    socket =
      socket
      |> TimelineState.put_future_windows(route_params.future_windows)
      |> TimelineState.put_show_external(route_params.show_external?)
      |> refresh_page_data()

    socket =
      socket
      |> sync_modal_with_route(route_modal(socket, route_params))

    {:noreply, socket}
  end

  # handle_event ===============================================================

  # LocationPicker -------------------------------------------------------------

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

  # Modals ---------------------------------------------------------------------

  # Close

  def handle_event("modal_close", _params, socket) do
    {:noreply, close_modal(socket)}
  end

  # External calendars

  @impl true
  def handle_event("toggle_external", _params, socket) do
    current_scope = socket.assigns.current_scope
    timeline = socket.assigns.timeline

    query = Params.page_query(!timeline.show_external?, timeline.future_windows)

    {:noreply, push_patch(socket, to: TimelineState.events_path(current_scope, query))}
  end

  def handle_event("external_calendar_subscription_start", _params, socket) do
    {:noreply, assign(socket, :modal, {:subscription, :new})}
  end

  def handle_event("external_calendar_subscription_show", %{"id" => id}, socket) do
    {:noreply, assign(socket, :modal, {:subscription, {:show, id}})}
  end

  # Event details

  def handle_event("external_event_show", %{"id" => id}, socket) do
    external_event =
      Enum.find(socket.assigns.timeline.external_items, &(&1.id == id))

    {:noreply, assign(socket, :modal, {:external_event, external_event})}
  end

  def handle_event("event_interest_start", %{"source_type" => "internal", "id" => id}, socket) do
    {:noreply, assign(socket, :modal, {:interest, :internal, id})}
  end

  def handle_event("event_interest_start", %{"source_type" => "external", "id" => id}, socket) do
    {:noreply, assign(socket, :modal, {:interest, :external, id})}
  end

  # Internal event creation

  def handle_event("event_create_start", _params, socket) do
    {:noreply, assign(socket, :modal, :event_form)}
  end

  # handle_info ================================================================

  def handle_info({:events_live, :close}, socket) do
    {:noreply, close_modal(socket)}
  end

  # Event details

  @impl true
  def handle_info({:event_details, :saved}, socket) do
    current_scope = socket.assigns.current_scope
    timeline = socket.assigns.timeline
    page_query = Params.page_query(timeline.show_external?, timeline.future_windows)

    socket =
      socket
      |> assign(:modal, nil)
      |> refresh_page_data()
      |> push_patch(to: TimelineState.events_path(current_scope, page_query))

    {:noreply, socket}
  end

  def handle_info({:event_details, :relay_completed}, socket) do
    {:noreply, put_flash(socket, :info, "Event relayed")}
  end

  def handle_info({:event_details, {:interest_failed, error}}, socket) do
    Log.scoped_error(
      socket.assigns.current_scope,
      error,
      "event interest update after event edit failed"
    )

    {:noreply, put_flash(socket, :error, "Event saved, but interest could not be updated")}
  end

  # Event creation

  def handle_info({:events_live, {:event_created, _event}}, socket) do
    current_scope = socket.assigns.current_scope
    timeline = socket.assigns.timeline
    page_query = Params.page_query(timeline.show_external?, timeline.future_windows)

    {:noreply,
     socket
     |> assign(:modal, nil)
     |> refresh_page_data()
     |> push_patch(to: TimelineState.events_path(current_scope, page_query))}
  end

  # Interest

  def handle_info({:events_live, {:interest_saved, _result}}, socket) do
    {:noreply,
     socket
     |> assign(:modal, nil)
     |> refresh_page_data()}
  end

  # Subscriptions

  def handle_info({:events_live, {:subscription_created, _subscription}}, socket) do
    {:noreply,
     socket
     |> assign(:modal, nil)
     |> refresh_page_data()}
  end

  def handle_info({:events_live, {:subscription_removed, _id}}, socket) do
    {:noreply,
     socket
     |> assign(:modal, nil)
     |> refresh_page_data()}
  end

  def handle_info({:events_live, {:subscription_updated, _id}}, socket) do
    {:noreply,
     socket
     |> assign(:modal, nil)
     |> refresh_page_data()}
  end

  def handle_info({:events_live, {:subscription_refreshed, id}}, socket) do
    {:noreply,
     socket
     |> refresh_page_data()
     |> assign(:modal, {:subscription, {:show, id}})}
  end

  # Flash

  def handle_info({:events_live, {:flash, level, message}}, socket) do
    {:noreply, put_flash(socket, level, message)}
  end

  # Helpers ====================================================================

  defp refresh_page_data(socket) do
    TimelineState.refresh_page_data(socket)
  end

  defp route_modal(_socket, %{event_id: event_id, external_event_id: external_event_id})
       when not is_nil(event_id) and not is_nil(external_event_id),
       do: nil

  defp route_modal(socket, %{event_id: event_id}) when not is_nil(event_id) do
    case Enum.find(socket.assigns.timeline.internal_publications, &(&1.event_id == event_id)) do
      nil -> nil
      publication -> {:internal_event, publication}
    end
  end

  defp route_modal(socket, %{external_event_id: external_event_id})
       when not is_nil(external_event_id) do
    case Enum.find(socket.assigns.timeline.external_items, &(&1.event.id == external_event_id)) do
      nil -> nil
      item -> {:external_event, item}
    end
  end

  defp route_modal(_socket, _route_params), do: nil

  defp sync_modal_with_route(socket, nil) do
    case socket.assigns.modal do
      {:internal_event, _publication} -> assign(socket, :modal, nil)
      {:external_event, _item} -> assign(socket, :modal, nil)
      _modal -> socket
    end
  end

  defp sync_modal_with_route(socket, modal) do
    assign(socket, :modal, modal)
  end

  defp close_modal(socket) do
    current_scope = socket.assigns.current_scope
    timeline = socket.assigns.timeline

    case socket.assigns.modal do
      {:internal_event, _publication} ->
        query =
          Params.page_query(timeline.show_external?, timeline.future_windows)

        socket
        |> assign(:modal, nil)
        |> push_patch(to: TimelineState.events_path(current_scope, query))

      {:external_event, _item} ->
        socket
        |> assign(:modal, nil)
        |> push_patch(
          to:
            TimelineState.events_path(
              current_scope,
              Params.page_query(true, timeline.future_windows)
            )
        )

      _ ->
        assign(socket, :modal, nil)
    end
  end

  defp modal_title(:event_form, _subscriptions), do: "Create event"

  defp modal_title({:interest, _source_type, _source_id}, _subscriptions),
    do: "Your interest / participation"

  defp modal_title({:subscription, :new}, _subscriptions), do: "Subscribe to calendar"

  defp modal_title({:subscription, {:show, subscription_id}}, subscriptions) do
    subscription = SubscriptionState.find(subscriptions, subscription_id)
    SubscriptionState.title(subscriptions, subscription)
  end

  defp modal_title(_modal, _subscriptions), do: nil
end
