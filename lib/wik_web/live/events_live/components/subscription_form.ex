defmodule WikWeb.EventsLive.Components.SubscriptionForm do
  use WikWeb, :live_component

  alias Wik.Events.ExternalCalendar
  alias Wik.Events.ExternalCalendarSubscription
  alias WikWeb.EventsLive.SubscriptionState

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:form, fn -> SubscriptionState.create_form() end)
      |> assign_new(:error, fn -> nil end)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        for={@form}
        id="events-subscription-form"
        data-testid="events-subscription-form"
        phx-submit="external_calendar_subscription_submit"
        phx-target={@myself}
      >
        <div class="space-y-4">
          <.input
            field={@form[:ics_url]}
            label="ICS URL"
            placeholder="https://example.com/calendar.ics"
          />

          <p
            :if={@error not in [nil, ""]}
            class="text-sm text-error"
            data-testid="events-subscription-form-error"
          >
            {@error}
          </p>

          <div class="flex justify-end gap-2">
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
    </div>
    """
  end

  @impl true
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
          sync_created_subscription(socket, subscription, ics_url)

        {:error, %Ash.Error.Invalid{} = error} ->
          assign_error(socket, ics_url, SubscriptionState.error_message(error))

        {:error, error} ->
          assign_error(socket, ics_url, SubscriptionState.error_message(error))
      end

    {:noreply, socket}
  end

  defp sync_created_subscription(socket, subscription, ics_url) do
    case ExternalCalendar.sync_subscription(subscription) do
      {:ok, subscription} ->
        send(self(), {:events_live, {:subscription_created, subscription}})
        socket

      {:error, error} ->
        _ =
          ExternalCalendarSubscription.destroy(subscription, scope: socket.assigns.current_scope)

        assign_error(socket, ics_url, SubscriptionState.error_message(error))
    end
  end

  defp assign_error(socket, ics_url, error) do
    socket
    |> assign(:form, SubscriptionState.create_form(ics_url))
    |> assign(:error, error)
  end
end
