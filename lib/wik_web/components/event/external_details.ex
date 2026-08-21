defmodule WikWeb.Components.Event.ExternalDetails do
  use WikWeb, :html

  alias Wik.Tags.Dimensions, as: TagDimensions
  alias WikWeb.Components.DimensionsList
  alias WikWeb.Components.Event

  attr :current_membership, :map, default: nil
  attr :current_scope, :map, default: nil
  attr :item, :map, required: true
  attr :user_tz, :string, required: true

  def render(assigns) do
    assigns = assign(assigns, :event, item_event(assigns.item))

    ~H"""
    <div class="space-y-5" data-testid="external-event-detail">
      <div>
        <div class="flex justify-between gap-2 mb-4">
          <h2 class={[
            "truncate text-base font-medium leading-tight",
            "flex-grow",
            @event.status == :cancelled && "line-through decoration-base-content"
          ]}>
            {@event.title}
          </h2>

          <Event.event_status event={@event} />
        </div>

        <div class="grid grid-cols-[1fr_auto] gap-4">
          <div>
            <Event.schedule class="text-sm opacity-70" event={@event} user_tz={@user_tz} />
          </div>
        </div>
      </div>

      <Event.Panels.Location.render location={@event.location} testid_prefix="external-event" />

      <Event.Panels.Participation.render
        current_membership={@current_membership}
        current_member_participation={@item.current_member_participation}
        participations={@item.participations}
        scope={@current_scope}
        source_id={@event.id}
        source_type="external"
        testid_prefix="external-event"
      />

      <.topics
        current_scope={@current_scope}
        topic_summaries={Map.get(@item, :topic_summaries, [])}
      />

      <Event.Panels.Description.render description={@event.description} />

      <div class="space-y-3">
        <dl :if={dev?() and present?(@item.external_uid)} class="space-y-1">
          <dt class="text-xs uppercase tracking-wide opacity-50">ICS event ID</dt>
          <dd class="text-xs opacity-70 break-all">{@item.external_uid}</dd>
        </dl>

        <dl :if={dev?() and present?(@item.external_recurrence_id)} class="space-y-1">
          <dt class="text-xs uppercase tracking-wide opacity-50">ICS recurrence ID</dt>
          <dd class="text-xs opacity-70 break-all">{@item.external_recurrence_id}</dd>
        </dl>

        <dl :if={present?(@item.calendar_name)} class="space-y-1">
          <dt class="text-xs uppercase tracking-wide opacity-50">Calendar</dt>
          <dd class="text-xs opacity-70">{@item.calendar_name}</dd>
        </dl>

        <dl :if={present?(@item.event_url)} class="space-y-1">
          <dt class="text-xs uppercase tracking-wide opacity-50">Event URL</dt>
          <dd class="text-sm break-all">
            <.link
              class="link link-hover underline decoration-dashed underline-offset-2"
              href={@item.event_url}
              rel="noopener noreferrer"
              target="_blank"
            >
              {@item.event_url}
            </.link>
          </dd>
        </dl>
      </div>
    </div>
    """
  end

  defp present?(value), do: value not in [nil, ""]

  defp dev?, do: Application.get_env(:wik, :show_external_event_debug_ids?, false)

  defp item_event(%{event: event}), do: event
  defp item_event(item), do: item

  attr :current_scope, :map, default: nil
  attr :topic_summaries, :list, default: []

  defp topics(assigns) do
    assigns =
      assign(
        assigns,
        :relevancy_dimension,
        TagDimensions.get!("external_calendar_subscription", "relevancy")
      )

    ~H"""
    <section :if={@topic_summaries != []} class="space-y-2" data-testid="external-event-topics">
      <h3 class="text-xs uppercase tracking-wide opacity-50">Topics</h3>

      <DimensionsList.render
        dimension={@relevancy_dimension}
        item_id={& &1.tag.id}
        items={@topic_summaries}
        level={& &1.average_relevancy}
        list_testid="external-event-topic-list"
        navigate={&~p"/#{@current_scope.tenant.slug}/topics/#{&1.tag.slug}"}
        testid_prefix="external-event-topic"
      >
        <:title :let={summary}>
          <div class="flex min-w-0 items-center gap-1.5">
            <.icon
              :if={Map.get(summary, :automatic?, false)}
              name="hero-sparkles-micro"
              class="size-3 shrink-0 text-base-content opacity-70"
            />
            <div class="truncate text-sm">{summary.tag.name}</div>
            <span :if={Map.get(summary, :automatic?, false)} class="sr-only">
              Detected from event text
            </span>
          </div>
        </:title>
      </DimensionsList.render>
    </section>
    """
  end
end
