defmodule WikWeb.EventsLive.Components.SubscriptionDetails do
  use WikWeb, :live_component

  alias Utils.Log
  alias Utils.Values
  alias Wik.Events.ExternalCalendar
  alias Wik.Events.ExternalCalendarSubscription
  alias WikWeb.Components.Time
  alias WikWeb.EventsLive.SubscriptionState

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:name_form, SubscriptionState.name_form(assigns.subscription))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div :if={@subscription} class="space-y-2">
        <div class="collapse collapse-plus bg-base-content/3 rounded">
          <input type="checkbox" />
          <div class="collapse-title label font-bold text-sm">Info</div>
          <div class="collapse-content text-sm space-y-4">
            <dl :if={@metadata.timezone} class="flex gap-4 items-center">
              <dt class="text-xs uppercase opacity-70">
                Timezone:
              </dt>

              <dd class="text-xs">
                {@metadata.timezone}
              </dd>
            </dl>

            <dl :if={@metadata.name} class="space-y-1">
              <dt class="text-xs uppercase opacity-70">
                Original name:
              </dt>
              <dd class="text-xs leading-tight bg-base-300/20 p-2 rounded text-base-content/90">
                {@metadata.name}
              </dd>
            </dl>

            <dl :if={@metadata.description} class="space-y-1">
              <dt class="text-xs uppercase opacity-70">
                Original description:
              </dt>
              <dd class="text-xs bg-base-300/20 p-2 rounded text-base-content/90">
                <div class="whitespace-pre-wrap">{@metadata.description}</div>
              </dd>
            </dl>

            <dl class="space-y-1">
              <dt class="text-xs uppercase opacity-70">Subscription URL:</dt>
              <dd>
                <input
                  class="input input-sm w-full border !cursor-text text-base-content/80 rounded bg-base-300/20"
                  value={@subscription.ics_url}
                  disabled
                />
              </dd>
            </dl>
          </div>
        </div>

        <div class="space-y-2 bg-base-content/3 rounded p-4">
          <dl :if={@subscription.cached_at} class="flex gap-4 items-center">
            <dt class="label font-bold text-sm">
              Last updated:
            </dt>
            <dd class="text-sm flex items-center gap-2">
              <Time.relative_and_precise
                datetime={@subscription.cached_at}
                direction="right"
                ago?
              />
              <div class="tooltip tooltip-accent tooltip-xs tooltip-right">
                <div class="tooltip-content text-xs">Refresh now</div>
                <button
                  class={["btn btn-circle btn-xs btn-accent btn-ghost"]}
                  data-testid={"events-subscription-refresh-#{@subscription.id}"}
                  phx-click="external_calendar_subscription_refresh"
                  phx-target={@myself}
                  phx-value-id={@subscription.id}
                  type="button"
                >
                  <.icon name="hero-arrow-path-micro" class="size-3" />
                </button>
              </div>
            </dd>
          </dl>

          <.form
            :if={@name_form != nil}
            for={@name_form}
            id="events-subscription-name-form"
            data-testid="events-subscription-name-form"
            phx-submit="external_calendar_subscription_name_submit"
            phx-target={@myself}
          >
            <div class="space-y-3 [&_label]:text-sm">
              <.input field={@name_form[:id]} type="hidden" />

              <.input
                field={@name_form[:custom_name]}
                label="Custom name (optional)"
                class="input input-sm w-full"
              />

              <div class="flex justify-between">
                <div class="flex gap-2">
                  <button
                    :if={Ash.can?({@subscription, :destroy}, @current_scope)}
                    class="btn btn-error btn-soft btn-sm"
                    data-testid={"events-subscription-remove-#{@subscription.id}"}
                    phx-click="external_calendar_subscription_remove"
                    phx-target={@myself}
                    phx-value-id={@subscription.id}
                    type="button"
                  >
                    <.icon name="hero-trash-mini" class="size-3" /> Remove subscription
                  </button>
                </div>

                <button
                  type="submit"
                  class="btn btn-accent btn-sm"
                  data-testid="events-subscription-name-submit"
                >
                  Save
                </button>
              </div>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("external_calendar_subscription_remove", %{"id" => id}, socket) do
    case ExternalCalendarSubscription.destroy(socket.assigns.subscription,
           scope: socket.assigns.current_scope
         ) do
      :ok ->
        removed(socket, id)

      {:ok, _subscription} ->
        removed(socket, id)

      {:error, error} ->
        flash_error(socket, error)
    end
  end

  def handle_event("external_calendar_subscription_refresh", %{"id" => id}, socket) do
    case ExternalCalendar.sync_subscription(socket.assigns.subscription) do
      {:ok, _subscription} ->
        send(self(), {:events_live, {:subscription_refreshed, id}})
        {:noreply, socket}

      {:error, error} ->
        Log.scoped_error(
          socket.assigns.current_scope,
          error,
          "external_calendar_subscription_refresh failed"
        )

        flash_error(socket, error)
    end
  end

  def handle_event(
        "external_calendar_subscription_name_submit",
        %{"subscription_name" => %{"id" => subscription_id, "custom_name" => custom_name}},
        socket
      ) do
    with {:ok, subscription} <-
           Ash.get(ExternalCalendarSubscription, subscription_id,
             scope: socket.assigns.current_scope
           ),
         {:ok, _updated_subscription} <-
           ExternalCalendarSubscription.update_custom_name(
             subscription,
             %{custom_name: Values.blank_to_nil(custom_name)},
             scope: socket.assigns.current_scope
           ) do
      send(self(), {:events_live, {:subscription_updated, subscription_id}})
      {:noreply, socket}
    else
      {:error, error} ->
        Log.scoped_error(
          socket.assigns.current_scope,
          error,
          "external_calendar_subscription_name_submit failed"
        )

        flash_error(socket, error)
    end
  end

  defp removed(socket, id) do
    send(self(), {:events_live, {:subscription_removed, id}})
    {:noreply, socket}
  end

  defp flash_error(socket, error) do
    send(self(), {:events_live, {:flash, :error, SubscriptionState.error_message(error)}})
    {:noreply, socket}
  end
end
