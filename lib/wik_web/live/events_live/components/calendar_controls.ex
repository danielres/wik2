defmodule WikWeb.EventsLive.Components.CalendarControls do
  use WikWeb, :html

  alias Wik.Events.Event
  alias Wik.Events.ExternalCalendarSubscription
  alias WikWeb.Components
  alias WikWeb.Components.UI
  alias WikWeb.EventsLive.SubscriptionState

  attr :timeline, :map, required: true
  attr :subscriptions, :map, required: true
  attr :current_scope, :map, required: true

  def render(assigns) do
    ~H"""
    <fieldset class="fieldset">
      <label class="label cursor-pointer flex justify-start items-center">
        <div class="w-8">
          <input
            type="checkbox"
            checked={@timeline.show_external?}
            class="toggle toggle-xs"
            data-testid="events-external-toggle"
            phx-click="toggle_external"
          />
        </div>
        <div class="text-sm">
          <span :if={not @timeline.show_external?}>Show external</span>
          <span :if={@timeline.show_external?}>External calendars:</span>
        </div>
      </label>

      <section
        :if={@timeline.show_external?}
        class="space-y-3"
        data-testid="events-subscriptions"
      >
        <div
          :if={@subscriptions.records == []}
          class="rounded-box border border-dashed border-base-300 bg-base-200/50 p-4 text-sm opacity-70"
          data-testid="events-subscriptions-empty"
        >
          No external calendars yet.
        </div>

        <div class="flex flex-wrap gap-1 items-center">
          <button
            :for={subscription <- SubscriptionState.sorted(@subscriptions)}
            class={[
              "btn btn-neutral btn-sm cursor-pointer opacity-80 hover:opacity-100 transition-opacity",
              "max-w-64 overflow-hidden text-ellipsis whitespace-nowrap"
            ]}
            data-testid={"events-subscription-open-#{subscription.id}"}
            phx-click="external_calendar_subscription_show"
            phx-value-id={subscription.id}
            type="button"
          >
            <div class="min-w-0">
              <div class="text-xs font-medium truncate flex items-center gap-1">
                <.icon name="hero-calendar-days-micro" class="opacity-60" />
                {SubscriptionState.display_name(@subscriptions, subscription)}
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

          <div class="tooltip tooltip-accent tooltip-bottom ml-1 flex items-center">
            <UI.button_plus
              :if={Ash.can?({ExternalCalendarSubscription, :create}, @current_scope)}
              data-testid="events-subscribe-to-calendar-button"
              phx-click="external_calendar_subscription_start"
            />
            <div class="tooltip-content text-xs">
              Add subscription
            </div>
          </div>
        </div>
      </section>

      <section :if={not @timeline.show_external?}>
        <label class="label cursor-pointer justify-start w-full">
          <div class="w-8">
            <Components.CalendarFeed.space_subscribe_button scope={@current_scope} />
          </div>
          <span class="text-sm">Subscribe</span>
        </label>

        <label class="label cursor-pointer justify-start w-full">
          <div class="w-8">
            <UI.button_plus
              :if={Ash.can?({Event, :create}, @current_scope)}
              data-testid="events-create-button"
              phx-click="event_create_start"
              class="scale-90"
            />
          </div>
          <span class="text-sm">Add internal event</span>
        </label>
      </section>
    </fieldset>
    """
  end
end
