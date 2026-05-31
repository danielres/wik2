defmodule WikWeb.EventsLive.Components do
  use WikWeb, :html

  alias Wik.Events.Event
  alias Wik.Events.ExternalCalendarSubscription
  alias WikWeb.Components
  alias WikWeb.Components.Event.Details
  alias WikWeb.Components.Time
  alias WikWeb.Components.UI
  alias WikWeb.EventsLive.Subscriptions

  attr :timeline, :map, required: true
  attr :subscriptions, :map, required: true
  attr :current_scope, :map, required: true

  def calendar_controls(assigns) do
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

  attr :modal, :any, required: true
  attr :modal_title, :string, required: false
  attr :modal_internal_event, :map, required: false
  attr :modal_external_event, :map, required: false
  attr :modal_event_form, :map, required: false
  attr :modal_new_subscription_form, :map, required: false
  attr :modal_new_subscription_error, :string, required: false
  attr :modal_selected_subscription, :map, required: false
  attr :modal_subscription_name_form, :map, required: false
  attr :subscriptions, :map, required: true
  attr :current_scope, :map, required: true
  attr :active_tz, :string, required: true

  def modal(assigns) do
    ~H"""
    <Components.Modal.render
      cancel="modal_close"
      cancel_testid={modal_close_testid(@modal)}
      open?={@modal != nil}
      testid={modal_dialog_testid(@modal)}
    >
      <:title :if={@modal_title}>
        {@modal_title}
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

      <div :if={@modal_selected_subscription != nil} class="space-y-2">
        <div class="collapse collapse-plus bg-base-content/3 rounded">
          <input type="checkbox" />
          <div class="collapse-title label font-bold text-sm">Info</div>
          <div class="collapse-content text-sm space-y-4">
            <dl
              :if={Subscriptions.metadata(@subscriptions, @modal_selected_subscription).timezone}
              class="flex gap-4 items-center"
            >
              <dt class="text-xs uppercase opacity-70">
                Timezone:
              </dt>

              <dd class="text-xs">
                {Subscriptions.metadata(@subscriptions, @modal_selected_subscription).timezone}
              </dd>
            </dl>

            <dl
              :if={Subscriptions.metadata(@subscriptions, @modal_selected_subscription).name}
              class="space-y-1"
            >
              <dt class="text-xs uppercase opacity-70">
                Original name:
              </dt>
              <dd class="text-xs leading-tight text-xs bg-base-300/20 p-2 rounded text-base-content/90">
                {Subscriptions.metadata(@subscriptions, @modal_selected_subscription).name}
              </dd>
            </dl>

            <dl
              :if={Subscriptions.metadata(@subscriptions, @modal_selected_subscription).description}
              class="space-y-1"
            >
              <dt class="text-xs uppercase opacity-70">
                Original description:
              </dt>
              <dd class="text-xs bg-base-300/20 p-2 rounded text-base-content/90">
                <% description =
                  Subscriptions.metadata(@subscriptions, @modal_selected_subscription).description %>
                <div class="whitespace-pre-wrap">{description}</div>
              </dd>
            </dl>

            <dl class="space-y-1">
              <dt class="text-xs uppercase opacity-70">Subscription URL:</dt>
              <dd>
                <input
                  class="input input-sm w-full border !cursor-text text-base-content/80 rounded bg-base-300/20"
                  value={@modal_selected_subscription.ics_url}
                  disabled
                />
              </dd>
            </dl>
          </div>
        </div>

        <div class="space-y-2 bg-base-content/3 rounded p-4">
          <dl
            :if={@modal_selected_subscription.cached_at}
            class="flex gap-4 items-center"
          >
            <dt class="label font-bold text-sm">
              Last updated:
            </dt>
            <dd class="text-sm flex items-center gap-2">
              <Time.relative_and_precise
                datetime={@modal_selected_subscription.cached_at}
                direction="right"
                ago?
              />
              <div class="tooltip tooltip-accent tooltip-xs tooltip-right">
                <div class="tooltip-content text-xs">Refresh now</div>
                <button
                  class={["btn btn-circle btn-xs btn-accent btn-ghost"]}
                  data-testid={"events-subscription-refresh-#{@modal_selected_subscription.id}"}
                  phx-click="external_calendar_subscription_refresh"
                  phx-value-id={@modal_selected_subscription.id}
                  type="button"
                >
                  <.icon name="hero-arrow-path-micro" class="size-3" />
                </button>
              </div>
            </dd>
          </dl>

          <.form
            :if={@modal_subscription_name_form != nil}
            for={@modal_subscription_name_form}
            id="events-subscription-name-form"
            data-testid="events-subscription-name-form"
            phx-submit="external_calendar_subscription_name_submit"
          >
            <div class="space-y-3 [&_label]:text-sm">
              <.input field={@modal_subscription_name_form[:id]} type="hidden" />

              <.input
                field={@modal_subscription_name_form[:custom_name]}
                label="Custom name (optional)"
                class="input input-sm w-full"
              />

              <div class="flex justify-between">
                <div class="flex gap-2">
                  <button
                    :if={Ash.can?({@modal_selected_subscription, :destroy}, @current_scope)}
                    class="btn btn-error btn-soft btn-sm"
                    data-testid={"events-subscription-remove-#{@modal_selected_subscription.id}"}
                    phx-click="external_calendar_subscription_remove"
                    phx-value-id={@modal_selected_subscription.id}
                    type="button"
                  >
                    <.icon name="hero-trash-mini" class="size-3" /> Remove subscription
                  </button>
                </div>

                <button
                  type="submit"
                  class="btn btn-accent  btn-sm"
                  data-testid="events-subscription-name-submit"
                >
                  Save
                </button>
              </div>
            </div>
          </.form>
        </div>
      </div>
    </Components.Modal.render>
    """
  end

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
end
