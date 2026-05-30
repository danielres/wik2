defmodule WikWeb.EventsLive do
  use WikWeb, :live_view

  alias AshPhoenix.Form
  alias Utils.Log
  alias Wik.Events.Event
  alias Wik.Events.ExternalCalendar
  alias Wik.Events.ExternalCalendarSubscription
  alias Wik.Locations
  alias WikWeb.Components
  alias WikWeb.Components.Event.Details
  alias WikWeb.Components.Event.FormState
  alias WikWeb.Components.Time
  alias WikWeb.Components.UI
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
          <div class="flex flex-wrap items-start gap-4 justify-between">
            <div class="flex items-center gap-2">
              <Components.CalendarFeed.space_subscribe_button scope={@current_scope} />

              <button
                :if={Ash.can?({ExternalCalendarSubscription, :create}, @current_scope)}
                class="btn btn-sm btn-ghost"
                data-testid="events-subscribe-to-calendar-button"
                phx-click="external_calendar_subscription_start"
              >
                Subscribe to calendar
              </button>
            </div>

            <UI.button_plus
              :if={Ash.can?({Event, :create}, @current_scope)}
              data-testid="events-create-button"
              phx-click="event_create_start"
            />
          </div>

          <section class="space-y-3" data-testid="events-subscriptions">
            <div class="flex items-center justify-between gap-3">
              <div>
                <h2 class="text-sm font-semibold">External calendars</h2>
                <p class="text-xs opacity-60">
                  ICS feeds subscribed for this space.
                </p>
              </div>
            </div>

            <div
              :if={@subscriptions.records == []}
              class="rounded-box border border-dashed border-base-300 bg-base-200/50 p-4 text-sm opacity-70"
              data-testid="events-subscriptions-empty"
            >
              No external calendars yet.
            </div>

            <div :if={@subscriptions.records != []} class="flex flex-wrap gap-2">
              <button
                :for={subscription <- Subscriptions.sorted(@subscriptions)}
                class={[
                  "btn btn-neutral btn-sm cursor-pointer opacity-80 hover:opacity-100 transition-opacity",
                  "max-w-64 overflow-hidden text-ellipsis whitespace-nowrap"
                ]}
                data-testid={"events-subscription-open-#{subscription.id}"}
                phx-click="external_calendar_subscription_show"
                phx-value-id={subscription.id}
              >
                <div class="min-w-0">
                  <div class="text-xs font-medium truncate flex items-center gap-1">
                    <.icon name="hero-calendar-days-micro" class="opacity-60" />
                    {Subscriptions.display_name(@subscriptions, subscription)}
                  </div>
                  <div
                    :if={Map.has_key?(@subscriptions.errors_by_id, subscription.id)}
                    class="mt-1 text-xs text-error"
                    data-testid={"events-subscription-error-#{subscription.id}"}
                  >
                    {Map.fetch!(@subscriptions.errors_by_id, subscription.id)}
                  </div>
                </div>
              </button>
            </div>
          </section>

          <Components.Event.grouped_timeline
            current_scope={@current_scope}
            grouped_items={@timeline.grouped_items}
            timeline_source={@timeline.source}
            user_tz={@active_tz}
          />
        </div>

        <Components.Modal.render
          cancel="modal_close"
          cancel_testid={modal_close_testid(@modal)}
          open?={@modal != nil}
          testid={modal_dialog_testid(@modal)}
        >
          <:title :if={@modal_title}>
            <h2 class="text-lg font-medium mb-8">{@modal_title}</h2>
          </:title>

          <.live_component
            :if={@modal_internal_event != nil}
            module={Details}
            id={"event-details-#{@modal_internal_event.id}"}
            current_scope={@current_scope}
            publication={@modal_internal_event}
            user_tz={@active_tz}
          />

          <Components.Event.ExternalDetails.render
            :if={@modal_external_event != nil}
            item={@modal_external_event}
            user_tz={@active_tz}
          />

          <Components.Event.event_form
            :if={@modal_event_form != nil}
            form={@modal_event_form}
            user_tz={@active_tz}
          />

          <.form
            :if={@modal_new_subscription_form != nil}
            for={@modal_new_subscription_form}
            id="events-subscription-form"
            data-testid="events-subscription-form"
            phx-submit="external_calendar_subscription_submit"
          >
            <div class="space-y-4">
              <.input
                field={@modal_new_subscription_form[:ics_url]}
                label="ICS URL"
                placeholder="https://example.com/calendar.ics"
              />

              <p
                :if={@modal_new_subscription_error not in [nil, ""]}
                class="text-sm text-error"
                data-testid="events-subscription-form-error"
              >
                {@modal_new_subscription_error}
              </p>

              <div class="flex justify-end gap-2">
                <button
                  type="button"
                  class="btn btn-ghost btn-sm"
                  data-testid="events-subscription-cancel"
                  phx-click="modal_close"
                >
                  Cancel
                </button>

                <button
                  type="submit"
                  class="btn btn-primary btn-sm"
                  data-testid="events-subscription-submit"
                >
                  Subscribe
                </button>
              </div>
            </div>
          </.form>

          <div :if={@modal_selected_subscription != nil} class="space-y-6">
            <div class="p-4 rounded-box space-y-4">
              <dl
                :if={@modal_selected_subscription.cached_at}
                class="flex gap-4 items-center"
              >
                <dt class="text-xs uppercase opacity-70">
                  Last updated:
                </dt>
                <dd class="text-sm">
                  <Time.relative_and_precise datetime={@modal_selected_subscription.cached_at} />
                </dd>
              </dl>

              <dl class="flex gap-4 items-center">
                <dt class="text-xs uppercase opacity-70">URL:</dt>
                <dd class="">
                  <input
                    class="input input-sm w-full border"
                    value={@modal_selected_subscription.ics_url}
                    disabled
                  />
                </dd>
              </dl>
            </div>

            <.form
              :if={@modal_subscription_name_form != nil}
              for={@modal_subscription_name_form}
              id="events-subscription-name-form"
              data-testid="events-subscription-name-form"
              phx-submit="external_calendar_subscription_name_submit"
            >
              <div class="space-y-3">
                <.input field={@modal_subscription_name_form[:id]} type="hidden" />

                <.input
                  field={@modal_subscription_name_form[:custom_name]}
                  label="Custom name (optional)"
                />

                <div class="flex justify-between">
                  <button
                    :if={Ash.can?({@modal_selected_subscription, :destroy}, @current_scope)}
                    class="btn btn-error btn-soft btn-sm"
                    data-testid={"events-subscription-remove-#{@modal_selected_subscription.id}"}
                    phx-click="external_calendar_subscription_remove"
                    phx-value-id={@modal_selected_subscription.id}
                    type="button"
                  >
                    Remove
                  </button>
                  <button
                    type="submit"
                    class="btn btn-accent btn-soft btn-sm"
                    data-testid="events-subscription-name-submit"
                  >
                    Save
                  </button>
                </div>
              </div>
            </.form>
          </div>
        </Components.Modal.render>
      </Layouts.space>
    </Layouts.app>
    """
  end

  @impl true
  def handle_params(params, _url, socket) do
    timeline_source = params["source"] || "both"

    publication =
      params["event"] &&
        Enum.find(socket.assigns.timeline.internal_publications, &(&1.id == params["event"]))

    socket =
      socket
      |> put_timeline_source(timeline_source)
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

    socket =
      case Form.submit(modal_event_form(socket),
             params: params,
             action_opts: [scope: current_scope]
           ) do
        {:ok, _event} ->
          socket
          |> assign(:modal, nil)
          |> refresh_page_data()
          |> push_patch(to: ~p"/#{current_scope.tenant.slug}/events")

        {:error, form} ->
          assign(socket, :modal, {:event_form, form})
      end

    {:noreply, socket}
  end

  def handle_event("event_form_cancel", _params, socket) do
    {:noreply, clear_event_form_modal(socket)}
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
      with {:ok, cache_attrs} <-
             ExternalCalendar.fetch_subscription_cache(%ExternalCalendarSubscription{
               ics_url: ics_url,
               space_id: scope.tenant.id,
               space: scope.tenant
             }),
           {:ok, _subscription} <-
             ExternalCalendarSubscription.create(
               Map.put(cache_attrs, :ics_url, ics_url),
               scope: scope
             ) do
        socket
        |> assign(:modal, nil)
        |> refresh_page_data()
      else
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

    socket =
      socket
      |> assign(:modal, nil)
      |> refresh_page_data()
      |> push_patch(to: ~p"/#{current_scope.tenant.slug}/events")

    {:noreply, socket}
  end

  def handle_info({:event_details, :relay_completed}, socket) do
    {:noreply, put_flash(socket, :info, "Event relayed")}
  end

  defp refresh_page_data(socket) do
    scope = socket.assigns.current_scope

    with {:ok, loaded_data} <- TimelineData.load(scope) do
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
            external_items: [],
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
        external_items: loaded_data.external_items
    })
    |> put_timeline_items()
  end

  defp put_loaded_subscriptions(socket, loaded_data) do
    subscriptions =
      socket.assigns.subscriptions
      |> Subscriptions.put_loaded_data(loaded_data)

    assign(socket, :subscriptions, subscriptions)
  end

  defp put_timeline_source(socket, source) do
    socket
    |> assign(:timeline, %{socket.assigns.timeline | source: source})
    |> put_timeline_items()
  end

  defp empty_timeline(source \\ "both") do
    %{
      source: source,
      internal_publications: [],
      external_items: [],
      items: [],
      grouped_items: []
    }
  end

  defp put_timeline_items(socket) do
    timeline = socket.assigns.timeline

    items =
      TimelineData.timeline_items(
        timeline.internal_publications,
        timeline.external_items,
        timeline.source
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

    case socket.assigns.modal do
      {:internal_event, _publication} ->
        socket
        |> assign(:modal, nil)
        |> push_patch(to: ~p"/#{current_scope.tenant.slug}/events")

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

  defp modal_dialog_testid({:subscription, _subscription, _name_form}),
    do: "events-subscription-detail-dialog"

  defp modal_dialog_testid({:new_subscription, _form, _error}),
    do: "events-subscription-modal-dialog"

  defp modal_dialog_testid(_modal), do: "event-modal-dialog"

  defp modal_close_testid({:subscription, _subscription, _name_form}),
    do: "events-subscription-detail-close"

  defp modal_close_testid({:new_subscription, _form, _error}),
    do: "events-subscription-modal-close"

  defp modal_close_testid(_modal), do: "event-modal-close"

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
