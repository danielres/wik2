defmodule WikWeb.Components.Event.Timeline do
  use WikWeb, :html

  alias Wik.Tags.Dimensions
  alias WikWeb.Components.Event
  alias WikWeb.Components.LevelMeter
  alias WikWeb.Components.User

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
                  <div class={[
                    "rounded-box",
                    "bg-base-content/6",
                    "border-[1.5px] border-base-content/20"
                  ]}>
                    <.link
                      patch={item.open_path}
                      class={[
                        "block p-4",
                        "hover:bg-base-content/14",
                        "transition",
                        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/40"
                      ]}
                      data-testid={"event-open-#{item.publication.id}"}
                    >
                      <.timeline_item_body
                        current_scope={@current_scope}
                        grouped_date={Date.new!(year_group.year, month_group.month, day_group.day)}
                        item={item}
                        user_tz={@user_tz}
                      />
                    </.link>

                    <.interest_button
                      current_member_participation={item.current_member_participation}
                      source_id={item.publication.id}
                      source_type="internal"
                      testid={"event-interest-#{item.publication.id}"}
                    />
                  </div>
                <% else %>
                  <div class={[
                    "rounded-box",
                    "w-full",
                    "opacity-60 hover:opacity-100 transition-opacity",
                    "border-[1.5px] border-dashed border-base-content/30"
                  ]}>
                    <button
                      type="button"
                      class={["cursor-pointer", "block p-4", "w-full", "text-left"]}
                      data-testid={"event-open-#{item.id}"}
                      phx-click="external_event_show"
                      phx-target={@target}
                      phx-value-id={item.id}
                    >
                      <.timeline_item_body
                        current_scope={@current_scope}
                        grouped_date={Date.new!(year_group.year, month_group.month, day_group.day)}
                        item={item}
                        user_tz={@user_tz}
                      />
                    </button>

                    <.interest_button
                      current_member_participation={nil}
                      source_id={item.event.id}
                      source_type="external"
                      testid={"external-event-interest-#{item.event.id}"}
                    />
                  </div>
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

  attr :items, :list, default: []
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
        :if={@items == []}
        id="event-publications-empty"
        class="rounded-box border border-dashed border-base-300 bg-base-200/70 p-6 text-sm opacity-70"
        data-testid="events-empty"
      >
        No upcoming events yet.
      </div>

      <article
        :for={item <- @items}
        id={"event-publication-#{item.publication.id}"}
        data-testid={"event-publication-#{item.publication.id}"}
        class="rounded-box bg-base-200 p-0 transition overflow-hidden"
      >
        <.link
          patch={legacy_event_link_target(@current_scope, item.publication)}
          class={[
            "block p-4 hover:bg-base-300/70 transition",
            "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/40"
          ]}
          data-testid={"event-open-#{item.publication.id}"}
        >
          <div class="min-w-0 space-y-1">
            <div class="flex flex-wrap items-center gap-2">
              <Event.event_header publication={item.publication} />
              <Event.event_status event={item.event} />
            </div>

            <div
              class="truncate text-sm opacity-80"
              data-testid={"event-schedule-#{item.publication.id}"}
            >
              <Event.schedule event={item.event} user_tz={@user_tz} />
            </div>

            <User.identity avatar_size="xs" class="text-xs opacity-60" membership={item.author} />
          </div>
        </.link>
      </article>
    </div>
    """
  end

  attr :current_scope, :map, required: true
  attr :grouped_date, :any, default: nil
  attr :item, :map, required: true
  attr :user_tz, :string, required: true

  defp timeline_item_body(assigns) do
    ~H"""
    <div class="min-w-0 space-y-1">
      <div class="flex flex-wrap items-center gap-2">
        <h2 class={[
          "text-base font-medium leading-tight",
          @item.event.status == :cancelled && "line-through decoration-base-content"
        ]}>
          {@item.event.title}
        </h2>

        <Event.event_status event={@item.event} />
      </div>

      <div class="truncate text-sm opacity-80" data-testid={timeline_schedule_testid(@item)}>
        <Event.schedule event={@item.event} grouped_date={@grouped_date} user_tz={@user_tz} />
      </div>

      <div
        :if={present?(@item.calendar_name)}
        class="truncate text-xs opacity-60 flex items-center gap-1"
        data-testid={"external-event-calendar-name-#{@item.id}"}
      >
        <.icon name="hero-calendar-days-micro" class="opacity-60" />
        {@item.calendar_name}
      </div>

      <div :if={@item.participations != []} class="flex flex-wrap items-center gap-2">
        <div
          :for={participation <- @item.participations}
          class="flex items-center gap-1"
          data-testid={"timeline-event-participation-#{participation.id}"}
        >
          <User.identity
            avatar_size="xs"
            class="text-xs opacity-70"
            link?={false}
            membership={participation.membership}
          />
          <LevelMeter.render
            dimension={interest_dimension()}
            label="Interest"
            level={participation.interest}
            testid={"timeline-event-participation-interest-#{participation.id}"}
            width_class="w-16"
          />
        </div>
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

  defp timeline_dom_id(%{source_type: :internal, publication: publication}),
    do: "event-publication-#{publication.id}"

  defp timeline_dom_id(item), do: "external-event-#{item.id}"

  defp timeline_testid(%{source_type: :internal, publication: publication}),
    do: "event-publication-#{publication.id}"

  defp timeline_testid(item), do: "external-event-#{item.id}"

  defp timeline_schedule_testid(%{source_type: :internal, publication: publication}),
    do: "event-schedule-#{publication.id}"

  defp timeline_schedule_testid(item), do: "external-event-schedule-#{item.id}"

  defp interest_dimension, do: Dimensions.get!("membership", "interest")

  defp dev?, do: Application.get_env(:wik, :show_external_event_debug_ids?, false)

  defp legacy_event_link_target(%{tenant: %{slug: space_slug}}, publication) do
    ~p"/#{space_slug}/events?#{%{event: publication.event_id}}"
  end

  defp legacy_event_link_target(_scope, publication) do
    ~p"/#{publication.space.slug}/events?#{%{event: publication.event_id}}"
  end

  attr :current_member_participation, :any, default: nil
  attr :source_id, :string, required: true
  attr :source_type, :string, required: true
  attr :testid, :string, required: true

  defp interest_button(assigns) do
    ~H"""
    <div class="p-4 pt-0">
      <button
        type="button"
        class="btn btn-sm btn-ghost"
        data-testid={@testid}
        phx-click="event_interest_start"
        phx-value-id={@source_id}
        phx-value-source_type={@source_type}
      >
        {if @current_member_participation, do: "Edit interest", else: "Add interest"}
      </button>
    </div>
    """
  end

  defp present?(value), do: value not in [nil, ""]
end
