defmodule WikWeb.EventsLive do
  use WikWeb, :live_view

  alias AshPhoenix.Form
  alias Utils.Log
  alias Utils.Values
  alias Wik.Events
  alias Wik.Events.ExternalCalendar
  alias Wik.Events.ExternalCalendarSubscription
  alias Wik.Locations
  alias WikWeb.Components
  alias WikWeb.Components.Event.FormState
  alias WikWeb.EventsLive
  alias WikWeb.EventsLive.Params
  alias WikWeb.EventsLive.SubscriptionState
  alias WikWeb.EventsLive.TimelineLoader
  alias WikWeb.EventsLive.TimelinePresenter

  on_mount {WikWeb.LiveUserAuth, :live_scope_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(modal: nil)
     |> assign(presences: [])
     |> assign(subscriptions: SubscriptionState.empty())
     |> assign(timeline: empty_timeline())
     |> refresh_page_data()}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :modal_view, modal_view(assigns))

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
      |> put_timeline_future_windows(route_params.future_windows)
      |> put_timeline_show_external(route_params.show_external?)
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
    current_scope = socket.assigns.current_scope
    active_tz = socket.assigns.active_tz
    form = FormState.new(current_scope, active_tz)

    {:noreply, assign(socket, :modal, {:event_form, form, FormState.show_end_date?(form)})}
  end

  def handle_event("event_form_validate", %{"form" => params}, socket) do
    show_end_date? = modal_event_form_show_end_date?(socket)

    params =
      FormState.normalize_hidden_end_date_params(
        modal_event_form(socket),
        params,
        show_end_date?
      )

    form =
      socket
      |> modal_event_form()
      |> FormState.validate(params)

    {:noreply,
     assign(
       socket,
       :modal,
       {:event_form, form, show_end_date? || FormState.show_end_date?(form)}
     )}
  end

  def handle_event("event_form_end_date_add", _params, socket) do
    {:noreply, put_modal_event_form_show_end_date(socket, true)}
  end

  def handle_event("event_form_end_date_remove", _params, socket) do
    form =
      socket
      |> modal_event_form()
      |> FormState.collapse_end_date()

    {:noreply, assign(socket, :modal, {:event_form, form, false})}
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
    show_end_date? = modal_event_form_show_end_date?(socket)

    params =
      FormState.normalize_hidden_end_date_params(
        modal_event_form(socket),
        params,
        show_end_date?
      )

    socket =
      case Form.submit(modal_event_form(socket),
             params: params,
             action_opts: [scope: current_scope]
           ) do
        {:ok, _event} ->
          page_params = Params.page_params(timeline.show_external?, timeline.future_windows)

          socket
          |> assign(:modal, nil)
          |> refresh_page_data()
          |> push_patch(to: ~p"/#{current_scope.tenant.slug}/events?#{page_params}")

        {:error, form} ->
          assign(
            socket,
            :modal,
            {:event_form, form, show_end_date? || FormState.show_end_date?(form)}
          )
      end

    {:noreply, socket}
  end

  def handle_event("event_form_cancel", _params, socket) do
    {:noreply, clear_event_form_modal(socket)}
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
    publication = Enum.find(socket.assigns.timeline.internal_publications, &(&1.id == id))
    item = Enum.find(socket.assigns.timeline.internal_items, &(&1.publication.id == id))

    {:noreply,
     assign(
       socket,
       :modal,
       {:event_interest, :internal, publication,
        interest_form(item && item.current_member_participation)}
     )}
  end

  def handle_event("event_interest_start", %{"source_type" => "external", "id" => id}, socket) do
    external_event =
      socket.assigns.timeline.external_items
      |> Enum.map(& &1.event)
      |> Enum.find(&(&1.id == id))

    {:noreply,
     assign(socket, :modal, {:event_interest, :external, external_event, interest_form()})}
  end

  def handle_event("event_interest_cancel", _params, socket) do
    {:noreply, assign(socket, :modal, nil)}
  end

  def handle_event("event_interest_submit", %{"interest" => params}, socket) do
    scope = socket.assigns.current_scope

    socket =
      case socket.assigns.modal do
        {:event_interest, :internal, publication, _form} ->
          case Events.record_interest(publication, params, scope: scope) do
            {:ok, _participation} -> after_interest_saved(socket)
            {:error, error} -> assign_interest_error(socket, params, error)
          end

        {:event_interest, :external, external_event, _form} ->
          case Events.record_external_interest(external_event, params, scope: scope) do
            {:ok, _result} -> after_interest_saved(socket)
            {:error, error} -> assign_interest_error(socket, params, error)
          end

        _modal ->
          socket
      end

    {:noreply, socket}
  end

  def handle_event("external_calendar_subscription_start", _params, socket) do
    {:noreply, assign(socket, :modal, {:new_subscription, SubscriptionState.create_form(), nil})}
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
                {:new_subscription, SubscriptionState.create_form(ics_url), error_message(error)}
              )
          end

        {:error, %Ash.Error.Invalid{} = error} ->
          assign(
            socket,
            :modal,
            {:new_subscription, SubscriptionState.create_form(ics_url),
             Ash.Error.to_error_class(error).message}
          )

        {:error, error} ->
          assign(
            socket,
            :modal,
            {:new_subscription, SubscriptionState.create_form(ics_url), error_message(error)}
          )
      end

    {:noreply, socket}
  end

  def handle_event("external_calendar_subscription_remove", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    socket =
      case SubscriptionState.find(socket.assigns.subscriptions, id) do
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
      case SubscriptionState.find(socket.assigns.subscriptions, id) do
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
               %{custom_name: Values.blank_to_nil(custom_name)},
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

  defp refresh_page_data(socket) do
    scope = socket.assigns.current_scope
    timeline = socket.assigns.timeline

    with {:ok, loaded_data} <-
           TimelineLoader.load(scope,
             show_external?: timeline.show_external?,
             future_windows: timeline.future_windows
           ) do
      presented_timeline = TimelinePresenter.build(loaded_data, timeline.show_external?)

      socket
      |> put_loaded_timeline(presented_timeline)
      |> put_loaded_subscriptions(presented_timeline)
    else
      {:error, error} ->
        Log.scoped_error(scope, error, "refresh_page_data failed")

        socket
        |> assign(:timeline, %{
          socket.assigns.timeline
          | internal_publications: [],
            internal_items: [],
            external_items: [],
            load_more_path: nil,
            more_external_future?: false,
            items: [],
            grouped_items: []
        })
        |> assign(:subscriptions, SubscriptionState.empty())
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
      |> SubscriptionState.put_loaded_data(loaded_data)

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
      load_more_path: nil,
      more_external_future?: false,
      items: [],
      grouped_items: []
    }
  end

  defp put_timeline_items(socket) do
    timeline = socket.assigns.timeline

    items =
      TimelinePresenter.timeline_items(
        timeline.internal_items,
        timeline.external_items,
        timeline.show_external?
      )

    current_scope = socket.assigns.current_scope
    items = with_timeline_item_paths(items, current_scope, timeline)

    assign(socket, :timeline, %{
      timeline
      | items: items,
        load_more_path: load_more_path(current_scope, timeline),
        grouped_items: TimelinePresenter.grouped_timeline_items(items)
    })
  end

  defp with_timeline_item_paths(items, current_scope, timeline) do
    Enum.map(items, fn
      %{source_type: :internal, publication: publication} = item ->
        Map.put(
          item,
          :open_path,
          internal_event_path(
            current_scope,
            publication.event_id,
            timeline.show_external?,
            timeline.future_windows
          )
        )

      item ->
        item
    end)
  end

  defp load_more_path(current_scope, %{show_external?: true, future_windows: future_windows}) do
    params = Params.load_more_params(true, future_windows)
    ~p"/#{current_scope.tenant.slug}/events?#{params}"
  end

  defp load_more_path(_current_scope, _timeline), do: nil

  defp internal_event_path(current_scope, event_id, show_external?, future_windows) do
    params = Params.event_params(event_id, show_external?, future_windows)
    ~p"/#{current_scope.tenant.slug}/events?#{params}"
  end

  defp select_subscription_modal(socket, subscription_id) do
    subscription = SubscriptionState.find(socket.assigns.subscriptions, subscription_id)

    assign(
      socket,
      :modal,
      {:subscription, subscription, SubscriptionState.name_form(subscription)}
    )
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
      {:event_form, _form, _show_end_date?} -> assign(socket, :modal, nil)
      _ -> socket
    end
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

  defp modal_event_form(%{assigns: %{modal: modal}}), do: modal_event_form(modal)
  defp modal_event_form({:event_form, form, _show_end_date?}), do: form
  defp modal_event_form(_modal), do: nil

  defp modal_event_form_show_end_date?(%{assigns: %{modal: modal}}),
    do: modal_event_form_show_end_date?(modal)

  defp modal_event_form_show_end_date?({:event_form, _form, show_end_date?}), do: show_end_date?
  defp modal_event_form_show_end_date?(_modal), do: false

  defp interest_form(participation \\ nil, error \\ nil) do
    %{
      "extra_info" => participation && participation.extra_info,
      "interest" => (participation && participation.interest) || 5
    }
    |> interest_form_from_params(error)
  end

  defp interest_form_from_params(params, error) do
    form = to_form(params, as: :interest)

    if error do
      Map.put(form, :errors, interest: {error_message(error), []})
    else
      form
    end
  end

  defp after_interest_saved(socket) do
    socket
    |> assign(:modal, nil)
    |> refresh_page_data()
  end

  defp assign_interest_error(socket, params, error) do
    case socket.assigns.modal do
      {:event_interest, source_type, source, _form} ->
        assign(
          socket,
          :modal,
          {:event_interest, source_type, source, interest_form_from_params(params, error)}
        )

      _modal ->
        put_flash(socket, :error, error_message(error))
    end
  end

  defp put_modal_event_form_show_end_date(socket, show_end_date?) do
    case socket.assigns.modal do
      {:event_form, form, _current_show_end_date?} ->
        assign(socket, :modal, {:event_form, form, show_end_date?})

      _ ->
        socket
    end
  end

  defp modal_view(assigns) do
    case assigns.modal do
      {:event_form, form, show_end_date?} ->
        %{
          kind: :event_form,
          title: if(form.source.type == :create, do: "Create event", else: "Edit event"),
          dialog_testid: "event-modal-dialog",
          close_testid: "event-modal-close",
          form: form,
          show_end_date?: show_end_date?
        }

      {:internal_event, publication} ->
        %{
          kind: :internal_event,
          title: nil,
          dialog_testid: "event-modal-dialog",
          close_testid: "event-modal-close",
          publication: publication
        }

      {:external_event, item} ->
        %{
          kind: :external_event,
          title: nil,
          dialog_testid: "event-modal-dialog",
          close_testid: "event-modal-close",
          item: item
        }

      {:event_interest, source_type, source, form} ->
        %{
          kind: :event_interest,
          title: "Your interest",
          dialog_testid: "event-interest-dialog",
          close_testid: "event-interest-cancel",
          form: form,
          source: source,
          source_type: source_type
        }

      {:new_subscription, form, error} ->
        %{
          kind: :new_subscription,
          title: "Subscribe to calendar",
          dialog_testid: "events-subscription-modal-dialog",
          close_testid: "events-subscription-modal-close",
          form: form,
          error: error
        }

      {:subscription, subscription, name_form} ->
        %{
          kind: :subscription,
          title: SubscriptionState.title(assigns.subscriptions, subscription),
          dialog_testid: "events-subscription-detail-dialog",
          close_testid: "events-subscription-detail-close",
          subscription: subscription,
          name_form: name_form,
          metadata: SubscriptionState.metadata(assigns.subscriptions, subscription)
        }

      nil ->
        nil
    end
  end

  defp error_message(%Ash.Error.Forbidden{}), do: "You are not allowed to manage subscriptions"

  defp error_message(%Ash.Error.Invalid{} = error) do
    case Ash.Error.to_error_class(error) do
      %{message: message} when is_binary(message) -> message
      _ -> Exception.message(error)
    end
  end

  defp error_message(error) when is_binary(error), do: error
  defp error_message(:invalid_interest), do: "Interest must be between 0 and 10"
  defp error_message(:membership_not_found), do: "Could not find your membership"
  defp error_message(error), do: Exception.message(error)
end
