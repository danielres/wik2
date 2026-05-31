defmodule WikWeb.EventsLive do
  use WikWeb, :live_view

  alias AshPhoenix.Form
  alias Utils.Log
  alias Wik.Events.ExternalCalendar
  alias Wik.Events.ExternalCalendarSubscription
  alias Wik.Locations
  alias WikWeb.Components
  alias WikWeb.Components.Event.FormState
  alias WikWeb.EventsLive
  alias WikWeb.EventsLive.RouteParams
  alias WikWeb.EventsLive.Subscriptions
  alias WikWeb.EventsLive.TimelineData

  on_mount {WikWeb.LiveUserAuth, :live_scope_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(modal: nil)
     |> assign(presences: [])
     |> assign(subscriptions: Subscriptions.empty())
     |> assign(timeline: empty_timeline())
     |> refresh_page_data()}
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign_modal_assigns()
      |> then(&assign(&1, :modal_title, modal_title(&1)))

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
            <EventsLive.Components.calendar_controls
              timeline={@timeline}
              subscriptions={@subscriptions}
              current_scope={@current_scope}
            />
          </div>

          <Components.Event.grouped_timeline
            current_scope={@current_scope}
            external_future_windows={@timeline.future_windows}
            grouped_items={@timeline.grouped_items}
            more_external_future?={@timeline.more_external_future?}
            show_external?={@timeline.show_external?}
            user_tz={@active_tz}
          />
        </div>

        <EventsLive.Components.modal
          active_tz={@active_tz}
          current_scope={@current_scope}
          modal={@modal}
          modal_event_form={@modal_event_form}
          modal_external_event={@modal_external_event}
          modal_internal_event={@modal_internal_event}
          modal_new_subscription_error={@modal_new_subscription_error}
          modal_new_subscription_form={@modal_new_subscription_form}
          modal_selected_subscription={@modal_selected_subscription}
          modal_subscription_name_form={@modal_subscription_name_form}
          modal_title={@modal_title}
          subscriptions={@subscriptions}
        />
      </Layouts.space>
    </Layouts.app>
    """
  end

  @impl true
  def handle_params(params, _url, socket) do
    route_params = RouteParams.parse(params)

    socket =
      socket
      |> put_timeline_future_windows(route_params.future_windows)
      |> put_timeline_show_external(route_params.show_external?)
      |> refresh_page_data()

    publication =
      params["event"] &&
        Enum.find(socket.assigns.timeline.internal_publications, &(&1.id == params["event"]))

    socket =
      socket
      |> sync_modal_with_route(publication)

    {:noreply, socket}
  end

  @impl true
  def handle_event("event_create_start", _params, socket) do
    current_scope = socket.assigns.current_scope
    active_tz = socket.assigns.active_tz

    {:noreply, assign(socket, :modal, {:event_form, FormState.new(current_scope, active_tz)})}
  end

  def handle_event("event_form_validate", %{"form" => params}, socket) do
    form =
      socket
      |> modal_event_form()
      |> FormState.validate(params)

    {:noreply, assign(socket, :modal, {:event_form, form})}
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
    timeline = socket.assigns.timeline

    socket =
      case Form.submit(modal_event_form(socket),
             params: params,
             action_opts: [scope: current_scope]
           ) do
        {:ok, _event} ->
          page_params = RouteParams.page_params(timeline.show_external?, timeline.future_windows)

          socket
          |> assign(:modal, nil)
          |> refresh_page_data()
          |> push_patch(to: ~p"/#{current_scope.tenant.slug}/events?#{page_params}")

        {:error, form} ->
          assign(socket, :modal, {:event_form, form})
      end

    {:noreply, socket}
  end

  def handle_event("event_form_cancel", _params, socket) do
    {:noreply, clear_event_form_modal(socket)}
  end

  def handle_event("toggle_external", _params, socket) do
    current_scope = socket.assigns.current_scope
    timeline = socket.assigns.timeline

    params = RouteParams.page_params(!timeline.show_external?, timeline.future_windows)

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

  def handle_event("external_calendar_subscription_start", _params, socket) do
    {:noreply, assign(socket, :modal, {:new_subscription, Subscriptions.create_form(), nil})}
  end

  def handle_event("external_calendar_subscription_show", %{"id" => id}, socket) do
    {:noreply, select_subscription_modal(socket, id)}
  end

  def handle_event(
        "external_calendar_subscription_submit",
        %{"subscription" => %{"ics_url" => ics_url}},
        socket
      ) do
    scope = socket.assigns.current_scope
    ics_url = String.trim(ics_url)

    socket =
      case ExternalCalendarSubscription.create(%{ics_url: ics_url}, scope: scope) do
        {:ok, subscription} ->
          case ExternalCalendar.sync_subscription(subscription) do
            {:ok, _subscription} ->
              socket
              |> assign(:modal, nil)
              |> refresh_page_data()

            {:error, error} ->
              _ = ExternalCalendarSubscription.destroy(subscription, scope: scope)

              assign(
                socket,
                :modal,
                {:new_subscription, Subscriptions.create_form(ics_url), error_message(error)}
              )
          end

        {:error, %Ash.Error.Invalid{} = error} ->
          assign(
            socket,
            :modal,
            {:new_subscription, Subscriptions.create_form(ics_url),
             Ash.Error.to_error_class(error).message}
          )

        {:error, error} ->
          assign(
            socket,
            :modal,
            {:new_subscription, Subscriptions.create_form(ics_url), error_message(error)}
          )
      end

    {:noreply, socket}
  end

  def handle_event("external_calendar_subscription_remove", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    socket =
      case Subscriptions.find(socket.assigns.subscriptions, id) do
        nil ->
          socket

        subscription ->
          case ExternalCalendarSubscription.destroy(subscription, scope: scope) do
            :ok ->
              socket
              |> assign(:modal, nil)
              |> refresh_page_data()

            {:ok, _subscription} ->
              socket
              |> assign(:modal, nil)
              |> refresh_page_data()

            {:error, error} ->
              put_flash(socket, :error, error_message(error))
          end
      end

    {:noreply, socket}
  end

  def handle_event("external_calendar_subscription_refresh", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    socket =
      case Subscriptions.find(socket.assigns.subscriptions, id) do
        nil ->
          socket

        subscription ->
          case ExternalCalendar.sync_subscription(subscription) do
            {:ok, _subscription} ->
              socket
              |> refresh_page_data()
              |> select_subscription_modal(id)

            {:error, error} ->
              Log.scoped_error(scope, error, "external_calendar_subscription_refresh failed")
              put_flash(socket, :error, error_message(error))
          end
      end

    {:noreply, socket}
  end

  def handle_event(
        "external_calendar_subscription_name_submit",
        %{"subscription_name" => %{"id" => subscription_id, "custom_name" => custom_name}},
        socket
      ) do
    scope = socket.assigns.current_scope

    socket =
      with {:ok, subscription} <-
             Ash.get(ExternalCalendarSubscription, subscription_id, scope: scope),
           {:ok, _updated_subscription} <-
             ExternalCalendarSubscription.update_custom_name(
               subscription,
               %{custom_name: blank_to_nil(custom_name)},
               scope: scope
             ) do
        socket
        |> refresh_page_data()
        |> assign(:modal, nil)
      else
        {:error, error} ->
          Log.scoped_error(scope, error, "external_calendar_subscription_name_submit failed")
          put_flash(socket, :error, error_message(error))
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:event_details, :saved}, socket) do
    current_scope = socket.assigns.current_scope
    timeline = socket.assigns.timeline
    page_params = RouteParams.page_params(timeline.show_external?, timeline.future_windows)

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

  defp refresh_page_data(socket) do
    scope = socket.assigns.current_scope
    timeline = socket.assigns.timeline

    with {:ok, loaded_data} <-
           TimelineData.load(scope,
             show_external?: timeline.show_external?,
             future_windows: timeline.future_windows
           ) do
      socket
      |> put_loaded_timeline(loaded_data)
      |> put_loaded_subscriptions(loaded_data)
    else
      {:error, error} ->
        Log.scoped_error(scope, error, "refresh_page_data failed")

        socket
        |> assign(:timeline, %{
          socket.assigns.timeline
          | internal_publications: [],
            internal_items: [],
            external_items: [],
            more_external_future?: false,
            items: [],
            grouped_items: []
        })
        |> assign(:subscriptions, Subscriptions.empty())
        |> put_flash(:error, "Could not load events")
    end
  end

  defp put_loaded_timeline(socket, loaded_data) do
    socket
    |> assign(:timeline, %{
      socket.assigns.timeline
      | internal_publications: loaded_data.internal_publications,
        internal_items: loaded_data.internal_items,
        external_items: loaded_data.external_items,
        more_external_future?: loaded_data.more_external_future?
    })
    |> put_timeline_items()
  end

  defp put_loaded_subscriptions(socket, loaded_data) do
    subscriptions =
      socket.assigns.subscriptions
      |> Subscriptions.put_loaded_data(loaded_data)

    assign(socket, :subscriptions, subscriptions)
  end

  defp put_timeline_show_external(socket, show_external?) do
    socket
    |> assign(:timeline, %{socket.assigns.timeline | show_external?: show_external?})
    |> put_timeline_items()
  end

  defp put_timeline_future_windows(socket, future_windows) do
    assign(socket, :timeline, %{socket.assigns.timeline | future_windows: future_windows})
  end

  defp empty_timeline(show_external? \\ false) do
    %{
      show_external?: show_external?,
      future_windows: 1,
      internal_publications: [],
      internal_items: [],
      external_items: [],
      more_external_future?: false,
      items: [],
      grouped_items: []
    }
  end

  defp put_timeline_items(socket) do
    timeline = socket.assigns.timeline

    items =
      TimelineData.timeline_items(
        timeline.internal_items,
        timeline.external_items,
        timeline.show_external?
      )

    assign(socket, :timeline, %{
      timeline
      | items: items,
        grouped_items: TimelineData.grouped_timeline_items(items)
    })
  end

  defp select_subscription_modal(socket, subscription_id) do
    subscription = Subscriptions.find(socket.assigns.subscriptions, subscription_id)
    assign(socket, :modal, {:subscription, subscription, Subscriptions.name_form(subscription)})
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

  defp clear_event_form_modal(socket) do
    case socket.assigns.modal do
      {:event_form, _form} -> assign(socket, :modal, nil)
      _ -> socket
    end
  end

  defp close_modal(socket) do
    current_scope = socket.assigns.current_scope
    timeline = socket.assigns.timeline

    case socket.assigns.modal do
      {:internal_event, _publication} ->
        params =
          RouteParams.page_params(timeline.show_external?, timeline.future_windows)

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

  defp assign_modal_assigns(assigns) do
    modal = assigns.modal

    assigns
    |> assign(:modal_event_form, modal_event_form(modal))
    |> assign(:modal_internal_event, modal_internal_event(modal))
    |> assign(:modal_external_event, modal_external_event(modal))
    |> assign(:modal_new_subscription_form, modal_new_subscription_form(modal))
    |> assign(:modal_new_subscription_error, modal_new_subscription_error(modal))
    |> assign(:modal_selected_subscription, modal_selected_subscription(modal))
    |> assign(:modal_subscription_name_form, modal_subscription_name_form(modal))
  end

  defp modal_event_form(%{assigns: %{modal: modal}}), do: modal_event_form(modal)
  defp modal_event_form({:event_form, form}), do: form
  defp modal_event_form(_modal), do: nil

  defp modal_internal_event({:internal_event, publication}), do: publication
  defp modal_internal_event(_modal), do: nil

  defp modal_external_event({:external_event, item}), do: item
  defp modal_external_event(_modal), do: nil

  defp modal_new_subscription_form({:new_subscription, form, _error}), do: form
  defp modal_new_subscription_form(_modal), do: nil

  defp modal_new_subscription_error({:new_subscription, _form, error}), do: error
  defp modal_new_subscription_error(_modal), do: nil

  defp modal_selected_subscription(%{assigns: %{modal: modal}}),
    do: modal_selected_subscription(modal)

  defp modal_selected_subscription({:subscription, subscription, _name_form}), do: subscription
  defp modal_selected_subscription(_modal), do: nil

  defp modal_subscription_name_form({:subscription, _subscription, name_form}), do: name_form
  defp modal_subscription_name_form(_modal), do: nil

  defp modal_title(assigns) do
    cond do
      assigns.modal_event_form != nil ->
        if(assigns.modal_event_form.source.type == :create,
          do: "Create event",
          else: "Edit event"
        )

      assigns.modal_new_subscription_form != nil ->
        "Subscribe to calendar"

      assigns.modal_selected_subscription != nil ->
        Subscriptions.title(assigns.subscriptions, assigns.modal_selected_subscription)

      true ->
        nil
    end
  end

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value

  defp error_message(%Ash.Error.Forbidden{}), do: "You are not allowed to manage subscriptions"

  defp error_message(%Ash.Error.Invalid{} = error) do
    case Ash.Error.to_error_class(error) do
      %{message: message} when is_binary(message) -> message
      _ -> Exception.message(error)
    end
  end

  defp error_message(error) when is_binary(error), do: error
  defp error_message(error), do: Exception.message(error)
end
