defmodule WikWeb.EventsLive.Components.Modal do
  use WikWeb, :html

  alias WikWeb.Components
  alias WikWeb.Components.Event.Details
  alias WikWeb.Components.Time

  attr :modal_view, :map, required: false
  attr :current_scope, :map, required: true
  attr :active_tz, :string, required: true

  def render(assigns) do
    ~H"""
    <Components.Modal.render
      cancel="modal_close"
      cancel_testid={@modal_view && @modal_view.close_testid}
      open?={@modal_view != nil}
      testid={@modal_view && @modal_view.dialog_testid}
    >
      <:title :if={@modal_view && @modal_view.title}>
        {@modal_view.title}
      </:title>

      <.live_component
        :if={@modal_view && @modal_view.kind == :internal_event}
        module={Details}
        id={"event-details-#{@modal_view.publication.id}"}
        current_scope={@current_scope}
        publication={@modal_view.publication}
        user_tz={@active_tz}
      />

      <Components.Event.ExternalDetails.render
        :if={@modal_view && @modal_view.kind == :external_event}
        item={@modal_view.item}
        user_tz={@active_tz}
      />

      <div :if={@modal_view && @modal_view.kind == :external_event} class="mt-4">
        <button
          type="button"
          class="btn btn-sm btn-ghost"
          data-testid={"external-event-detail-interest-#{@modal_view.item.event.id}"}
          phx-click="event_interest_start"
          phx-value-id={@modal_view.item.event.id}
          phx-value-source_type="external"
        >
          Add interest
        </button>
      </div>

      <Components.Event.event_form
        :if={@modal_view && @modal_view.kind == :event_form}
        form={@modal_view.form}
        interest_form={@modal_view.interest_form}
        show_end_date?={@modal_view.show_end_date?}
        user_tz={@active_tz}
      />

      <.form
        :if={@modal_view && @modal_view.kind == :event_interest}
        for={@modal_view.form}
        id="event-interest-form"
        data-testid="event-interest-form"
        phx-submit="event_interest_submit"
      >
        <div class="space-y-4">
          <Components.Event.interest_fields form={@modal_view.form} />

          <div class="flex justify-end">
            <%!-- <button --%>
            <%!--   type="button" --%>
            <%!--   class="btn btn-ghost btn-sm" --%>
            <%!--   data-testid="event-interest-cancel" --%>
            <%!--   phx-click="event_interest_cancel" --%>
            <%!-- > --%>
            <%!--   Cancel --%>
            <%!-- </button> --%>

            <button type="submit" class="btn btn-accent btn-sm" data-testid="event-interest-submit">
              Save
            </button>
          </div>
        </div>
      </.form>

      <.form
        :if={@modal_view && @modal_view.kind == :new_subscription}
        for={@modal_view.form}
        id="events-subscription-form"
        data-testid="events-subscription-form"
        phx-submit="external_calendar_subscription_submit"
      >
        <div class="space-y-4">
          <.input
            field={@modal_view.form[:ics_url]}
            label="ICS URL"
            placeholder="https://example.com/calendar.ics"
          />

          <p
            :if={@modal_view.error not in [nil, ""]}
            class="text-sm text-error"
            data-testid="events-subscription-form-error"
          >
            {@modal_view.error}
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

      <div :if={@modal_view && @modal_view.kind == :subscription} class="space-y-2">
        <div class="collapse collapse-plus bg-base-content/3 rounded">
          <input type="checkbox" />
          <div class="collapse-title label font-bold text-sm">Info</div>
          <div class="collapse-content text-sm space-y-4">
            <dl :if={@modal_view.metadata.timezone} class="flex gap-4 items-center">
              <dt class="text-xs uppercase opacity-70">
                Timezone:
              </dt>

              <dd class="text-xs">
                {@modal_view.metadata.timezone}
              </dd>
            </dl>

            <dl :if={@modal_view.metadata.name} class="space-y-1">
              <dt class="text-xs uppercase opacity-70">
                Original name:
              </dt>
              <dd class="text-xs leading-tight text-xs bg-base-300/20 p-2 rounded text-base-content/90">
                {@modal_view.metadata.name}
              </dd>
            </dl>

            <dl :if={@modal_view.metadata.description} class="space-y-1">
              <dt class="text-xs uppercase opacity-70">
                Original description:
              </dt>
              <dd class="text-xs bg-base-300/20 p-2 rounded text-base-content/90">
                <div class="whitespace-pre-wrap">{@modal_view.metadata.description}</div>
              </dd>
            </dl>

            <dl class="space-y-1">
              <dt class="text-xs uppercase opacity-70">Subscription URL:</dt>
              <dd>
                <input
                  class="input input-sm w-full border !cursor-text text-base-content/80 rounded bg-base-300/20"
                  value={@modal_view.subscription.ics_url}
                  disabled
                />
              </dd>
            </dl>
          </div>
        </div>

        <div class="space-y-2 bg-base-content/3 rounded p-4">
          <dl :if={@modal_view.subscription.cached_at} class="flex gap-4 items-center">
            <dt class="label font-bold text-sm">
              Last updated:
            </dt>
            <dd class="text-sm flex items-center gap-2">
              <Time.relative_and_precise
                datetime={@modal_view.subscription.cached_at}
                direction="right"
                ago?
              />
              <div class="tooltip tooltip-accent tooltip-xs tooltip-right">
                <div class="tooltip-content text-xs">Refresh now</div>
                <button
                  class={["btn btn-circle btn-xs btn-accent btn-ghost"]}
                  data-testid={"events-subscription-refresh-#{@modal_view.subscription.id}"}
                  phx-click="external_calendar_subscription_refresh"
                  phx-value-id={@modal_view.subscription.id}
                  type="button"
                >
                  <.icon name="hero-arrow-path-micro" class="size-3" />
                </button>
              </div>
            </dd>
          </dl>

          <.form
            :if={@modal_view.name_form != nil}
            for={@modal_view.name_form}
            id="events-subscription-name-form"
            data-testid="events-subscription-name-form"
            phx-submit="external_calendar_subscription_name_submit"
          >
            <div class="space-y-3 [&_label]:text-sm">
              <.input field={@modal_view.name_form[:id]} type="hidden" />

              <.input
                field={@modal_view.name_form[:custom_name]}
                label="Custom name (optional)"
                class="input input-sm w-full"
              />

              <div class="flex justify-between">
                <div class="flex gap-2">
                  <button
                    :if={Ash.can?({@modal_view.subscription, :destroy}, @current_scope)}
                    class="btn btn-error btn-soft btn-sm"
                    data-testid={"events-subscription-remove-#{@modal_view.subscription.id}"}
                    phx-click="external_calendar_subscription_remove"
                    phx-value-id={@modal_view.subscription.id}
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
end
