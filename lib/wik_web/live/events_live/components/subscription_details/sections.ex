defmodule WikWeb.EventsLive.Components.SubscriptionDetails.Sections do
  use WikWeb, :live_component

  alias Wik.Tags.Dimensions
  alias WikWeb.Components.DimensionsList
  alias WikWeb.Components.RangeInput
  alias WikWeb.Components.Time
  alias WikWeb.EventsLive.Components.TopicMatching

  attr :myself, :any, required: true
  attr :subscription, :map, required: true

  def last_updated(assigns) do
    ~H"""
    <dl :if={@subscription.cached_at} class="flex gap-4 items-center">
      <dt class="font-bold text-sm">
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
    """
  end

  attr :metadata, :map, required: true
  attr :subscription, :map, required: true

  def info(assigns) do
    ~H"""
    <input type="checkbox" />
    <div class="collapse-title font-bold text-sm">Info</div>
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
    """
  end

  attr :current_membership, :map, default: nil
  attr :current_scope, :map, required: true
  attr :myself, :any, required: true
  attr :subscription, :map, required: true
  attr :subscription_topic_form, :any, default: nil
  attr :subscription_topic_options, :list, required: true
  attr :subscription_topic_summaries, :list, required: true

  def topics_always_applied(assigns) do
    ~H"""
    <% relevancy_dimension =
      Dimensions.get!("external_calendar_subscription", "relevancy") %>

    <div class="space-y-2">
      <div class="flex justify-between gap-2 items-baseline">
        <div>
          <div class="font-bold text-sm">Topics: always applied</div>
          <p class="text-xs text-base-content/55">
            These topics apply to every event from this calendar.
          </p>
        </div>

        <button
          :if={
            can_manage_subscription?(@subscription, @current_scope) and
              @current_membership != nil and @subscription_topic_options != []
          }
          type="button"
          class="btn btn-circle btn-xs btn-accent btn-soft"
          data-testid="events-subscription-topic-add"
          phx-click="subscription_topic_add_start"
          phx-target={@myself}
        >
          <span class="sr-only">Add topic</span>
          <.icon name="hero-plus-mini" class="size-3" />
        </button>
      </div>

      <DimensionsList.render
        dimension={relevancy_dimension}
        item_id={& &1.tag.id}
        items={@subscription_topic_summaries}
        level={& &1.average_relevancy}
        list_testid="events-subscription-topic-list"
        navigate={&~p"/#{@current_scope.tenant.slug}/topics/#{&1.tag.slug}"}
        testid_prefix="events-subscription-topic"
      >
        <:title :let={summary}>
          <div class="truncate text-sm">{summary.tag.name}</div>
        </:title>

        <:action :let={summary}>
          <button
            :if={
              can_manage_subscription?(@subscription, @current_scope) and
                summary.current_member_tagging
            }
            type="button"
            class={[
              "btn btn-xs btn-circle btn-ghost text-error",
              "opacity-50 hover:opacity-100 transition-opacity"
            ]}
            data-testid={"events-subscription-topic-remove-#{summary.tag.id}"}
            phx-click="subscription_topic_remove"
            phx-target={@myself}
            phx-value-tag_id={summary.tag.id}
          >
            <span class="sr-only">Remove topic</span>
            <.icon name="hero-x-mark" class="size-3" />
          </button>
        </:action>
      </DimensionsList.render>

      <.form
        :if={@subscription_topic_form}
        for={@subscription_topic_form}
        id="events-subscription-topic-form"
        class="space-y-3 rounded-box border border-base-300 bg-base-100 p-3"
        data-testid="events-subscription-topic-form"
        phx-change="subscription_topic_validate"
        phx-submit="subscription_topic_submit"
        phx-target={@myself}
      >
        <.input
          field={@subscription_topic_form[:tag_id]}
          label="Topic"
          options={Enum.map(@subscription_topic_options, &{&1.name, &1.id})}
          prompt="Select a topic"
          type="select"
        />

        <RangeInput.render
          field={@subscription_topic_form[:relevancy_level]}
          dimension={relevancy_dimension}
          label={relevancy_dimension.label}
          max_level={relevancy_dimension.max}
        />

        <div class="flex justify-end gap-2">
          <button
            type="button"
            class="btn btn-ghost btn-sm"
            data-testid="events-subscription-topic-cancel"
            phx-click="subscription_topic_cancel"
            phx-target={@myself}
          >
            Cancel
          </button>

          <.button
            class="btn btn-accent btn-soft btn-sm"
            data-testid="events-subscription-topic-submit"
          >
            Save
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  attr :current_scope, :map, required: true
  attr :subscription, :map, required: true
  attr :topic_matching_view, :map, required: true

  def topics_automatic_matching(assigns) do
    ~H"""
    <.live_component
      module={TopicMatching}
      id={"events-topic-matching-#{@subscription.id}"}
      can_manage?={can_manage_subscription?(@subscription, @current_scope)}
      current_scope={@current_scope}
      subscription={@subscription}
      view={@topic_matching_view}
    />
    """
  end

  attr :current_scope, :map, required: true
  attr :myself, :any, required: true
  attr :name_form, :any, default: nil
  attr :subscription, :map, required: true

  def form_custom_name(assigns) do
    ~H"""
    <.form
      :if={@name_form != nil}
      for={@name_form}
      id="events-subscription-name-form"
      data-testid="events-subscription-name-form"
      phx-submit="external_calendar_subscription_name_submit"
      phx-target={@myself}
    >
      <div class="space-y-3 [&_label]:text-sm [&_label]:opacity-100">
        <.input field={@name_form[:id]} type="hidden" />

        <.input
          field={@name_form[:custom_name]}
          label="Calendar: custom name (optional)"
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
    """
  end

  defp can_manage_subscription?(nil, _scope), do: false

  defp can_manage_subscription?(subscription, scope) do
    Ash.can?({subscription, :update_custom_name}, scope)
  end
end
