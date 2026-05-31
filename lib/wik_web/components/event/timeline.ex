defmodule WikWeb.Components.Event.Timeline do
  use WikWeb, :html

  alias WikWeb.Components.Event.AuthorLine
  alias WikWeb.Components.Event

  attr :current_scope, :map, required: true
  attr :grouped_items, :list, default: []
  attr :load_more_path, :string, default: nil
  attr :more_external_future?, :boolean, default: false
  attr :show_external?, :boolean, default: false
  attr :target, :any, default: nil
  attr :user_tz, :string, required: true

  def grouped_list(assigns) do
    ~H"""
    <div class="space-y-6" data-testid="events-timeline">
      <div
        :if={@grouped_items == []}
        class="rounded-box border border-dashed border-base-300 bg-base-200/70 p-6 text-sm opacity-70"
        data-testid="events-empty"
      >
        No upcoming events yet.
      </div>

      <section
        :for={year_group <- @grouped_items}
        class="space-y-0"
        id={"events-year-#{year_group.year}"}
        data-testid={"events-year-#{year_group.year}"}
      >
        <h2 class={["text-xl font-semibold", "sticky top-9 bg-base-100 z-40 pt-4"]}>
          {year_group.year}
        </h2>

        <section
          :for={month_group <- year_group.months}
          id={"events-month-#{year_group.year}-#{month_group.month}"}
          data-testid={"events-month-#{year_group.year}-#{month_group.month}"}
          class=""
        >
          <h3 class={[
            "text-sm font-semibold uppercase tracking-wide text-base-content/80",
            "sticky top-19 bg-base-100 z-30"
          ]}>
            {month_group.label}
          </h3>

          <section
            :for={day_group <- month_group.days}
            class="space-y-3 pt-3"
            id={"events-day-#{year_group.year}-#{month_group.month}-#{day_group.day}"}
            data-testid={"events-day-#{year_group.year}-#{month_group.month}-#{day_group.day}"}
          >
            <h4 class={[
              "text-sm font-medium tracking-wide text-base-content/70",
              "sticky top-23 bg-base-100 z-20",
              "pb-2"
            ]}>
              {day_group.label}
            </h4>

            <div class="grid gap-1 mb-8">
              <article
                :for={item <- day_group.items}
                id={timeline_dom_id(item)}
                data-testid={timeline_testid(item)}
                class={[]}
              >
                <%= if item.source_type == :internal do %>
                  <.link
                    patch={item.open_path}
                    class={[
                      "block p-4 rounded-box",
                      "bg-base-content/6",
                      "hover:bg-base-content/14",
                      "transition",
                      "border-[1.5px] border-base-content/20",
                      "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/40"
                    ]}
                    data-testid={"event-open-#{item.publication_id}"}
                  >
                    <.timeline_item_body
                      current_scope={@current_scope}
                      item={item}
                      user_tz={@user_tz}
                    />
                  </.link>
                <% else %>
                  <button
                    type="button"
                    class={[
                      "cursor-pointer",
                      "block p-4 rounded-box",
                      "w-full",
                      "text-left",
                      "opacity-60 hover:opacity-100 transition-opacity",
                      "border-[1.5px] border-dashed border-base-content/30"
                    ]}
                    data-testid={"event-open-#{item.id}"}
                    phx-click="external_event_show"
                    phx-target={@target}
                    phx-value-id={item.id}
                  >
                    <.timeline_item_body
                      current_scope={@current_scope}
                      item={item}
                      user_tz={@user_tz}
                    />
                  </button>
                <% end %>
              </article>
            </div>
          </section>
        </section>
      </section>

      <div :if={@more_external_future? and @show_external?} class="flex justify-center">
        <.link
          patch={@load_more_path}
          class="btn btn-sm btn-ghost"
          data-testid="events-load-more-future"
        >
          Load more future events
        </.link>
      </div>
    </div>
    """
  end

  attr :event_publications, :list, default: []
  attr :current_scope, :map, required: true
  attr :user_tz, :string, required: true

  def compact_list(assigns) do
    ~H"""
    <div
      id="event-publications"
      class="grid gap-1"
      data-testid="events-timeline"
    >
      <div
        :if={@event_publications == []}
        id="event-publications-empty"
        class="rounded-box border border-dashed border-base-300 bg-base-200/70 p-6 text-sm opacity-70"
        data-testid="events-empty"
      >
        No upcoming events yet.
      </div>

      <article
        :for={publication <- @event_publications}
        id={"event-publication-#{publication.id}"}
        data-testid={"event-publication-#{publication.id}"}
        class="rounded-box bg-base-200 p-0 transition overflow-hidden"
      >
        <.link
          patch={legacy_event_link_target(@current_scope, publication)}
          class={[
            "block p-4 hover:bg-base-300/70 transition",
            "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/40"
          ]}
          data-testid={"event-open-#{publication.id}"}
        >
          <div class="min-w-0 space-y-1">
            <div class="flex flex-wrap items-center gap-2">
              <Event.event_header publication={publication} />
              <Event.event_status event={publication.event} />
            </div>

            <div class="truncate text-sm opacity-80" data-testid={"event-schedule-#{publication.id}"}>
              <Event.schedule event={publication.event} user_tz={@user_tz} />
            </div>

            <AuthorLine.render
              display_name={publication.event.author |> to_string()}
              tenant={@current_scope.tenant}
              user={publication.event.author}
            />
          </div>
        </.link>
      </article>
    </div>
    """
  end

  attr :current_scope, :map, required: true
  attr :item, :map, required: true
  attr :user_tz, :string, required: true

  defp timeline_item_body(assigns) do
    ~H"""
    <div class="min-w-0 space-y-1">
      <div class="flex flex-wrap items-center gap-2">
        <h2 class={[
          "text-base font-medium leading-tight",
          @item.status == :cancelled && "line-through decoration-base-content"
        ]}>
          {@item.title}
        </h2>

        <Event.event_status event={@item} />
      </div>

      <div class="truncate text-sm opacity-80" data-testid={timeline_schedule_testid(@item)}>
        <Event.schedule event={@item} user_tz={@user_tz} />
      </div>

      <AuthorLine.render
        avatar_url={@item.author_avatar_url}
        display_name={@item.author_name}
        tenant={@current_scope.tenant}
        testid={"internal-event-author-#{@item.id}"}
        user={@item.author_user}
      />

      <div
        :if={present?(@item.calendar_name)}
        class="truncate text-xs opacity-60 flex items-center gap-1"
        data-testid={"external-event-calendar-name-#{@item.id}"}
      >
        <.icon name="hero-calendar-days-micro" class="opacity-60" />
        {@item.calendar_name}
      </div>

      <div
        :if={dev?() and present?(@item.external_uid)}
        class="text-[11px] opacity-45 break-all"
      >
        ICS: {@item.external_uid}
        <span :if={present?(@item.external_recurrence_id)}>
          {" · "}Recurrence: {@item.external_recurrence_id}
        </span>
      </div>
    </div>
    """
  end

  defp timeline_dom_id(%{source_type: :internal, publication_id: publication_id}),
    do: "event-publication-#{publication_id}"

  defp timeline_dom_id(item), do: "external-event-#{item.id}"

  defp timeline_testid(%{source_type: :internal, publication_id: publication_id}),
    do: "event-publication-#{publication_id}"

  defp timeline_testid(item), do: "external-event-#{item.id}"

  defp timeline_schedule_testid(%{source_type: :internal, publication_id: publication_id}),
    do: "event-schedule-#{publication_id}"

  defp timeline_schedule_testid(item), do: "external-event-schedule-#{item.id}"

  defp dev?, do: Application.get_env(:wik, :show_external_event_debug_ids?, false)

  defp legacy_event_link_target(%{tenant: %{slug: space_slug}}, publication) do
    ~p"/#{space_slug}/events?#{%{event: publication.id}}"
  end

  defp legacy_event_link_target(_scope, publication) do
    ~p"/#{publication.space.slug}/events?#{%{event: publication.id}}"
  end

  defp present?(value), do: value not in [nil, ""]
end
