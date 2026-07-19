defmodule WikWeb.EventsLive.Components.CalendarControls do
  use WikWeb, :html

  alias Wik.Events.ExternalCalendarSubscription
  alias WikWeb.Components
  alias WikWeb.Components.UI
  alias WikWeb.EventsLive.SubscriptionState

  attr :timeline, :map, required: true
  attr :subscriptions, :map, required: true
  attr :current_scope, :map, required: true

  def render(assigns) do
    ~H"""
    <div class="flex justify-between gap-4 items-center">
      <.toggle_external timeline={@timeline} />

      <div
        :if={@timeline.show_external?}
        class="tooltip tooltip-accent tooltip-bottom ml-1 flex items-center"
      >
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

    <div
      :if={@timeline.show_external?}
      data-testid="events-subscriptions"
    >
      <.external_sources subscriptions={@subscriptions} />
    </div>

    <label :if={false} class="label cursor-pointer justify-start w-full">
      <div class="w-8">
        <Components.CalendarFeed.space_subscribe_button scope={@current_scope} />
      </div>
      <span class="text-sm">Subscribe</span>
    </label>
    """
  end

  attr :timeline, :map, required: true

  defp toggle_external(assigns) do
    ~H"""
    <label class={[
      "label cursor-pointer",
      "flex items-center"
    ]}>
      <input
        type="checkbox"
        checked={@timeline.show_external?}
        class="toggle toggle-xs"
        data-testid="events-external-toggle"
        phx-click="toggle_external"
      />

      <h3 class={[
        "text-sm small-caps tracking-wider font-bold",
        (@timeline.show_external? && "text-base-content/80") || "text-base-content/50"
      ]}>
        External sources
      </h3>
    </label>
    """
  end

  attr :subscriptions, :map, required: true

  defp external_sources(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-1 items-center">
      <button
        :for={subscription <- SubscriptionState.sorted(@subscriptions)}
        class={[
          "btn bg-base-300/60 btn-xs cursor-pointer opacity-80 hover:opacity-100 transition-opacity",
          "max-w-64 overflow-hidden text-ellipsis whitespace-nowrap"
        ]}
        data-testid={"events-subscription-open-#{subscription.id}"}
        phx-click="external_calendar_subscription_show"
        phx-value-id={subscription.id}
        type="button"
      >
        <div class="min-w-0">
          <div class="text-xs font-medium truncate flex items-center gap-1">
            <.icon name="hero-calendar-micro" class="opacity-60" />
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
    </div>
    """
  end
end
