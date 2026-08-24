defmodule WikWeb.Components.Event.Timeline do
  use WikWeb, :html

  alias Wik.Events.Dimensions
  alias WikWeb.Components.Event
  alias WikWeb.Components.LevelMeter
  alias WikWeb.Components.User
  alias WikWeb.Components.UI

  attr :current_scope, :map, required: true
  attr :grouped_items, :list, default: []
  attr :load_more_path, :string, default: nil
  attr :mask_class, :string, default: "bg-base-100"
  attr :more_external_future?, :boolean, default: false
  attr :show_external?, :boolean, default: false
  attr :source_label_mode, :atom, default: :local
  attr :target, :any, default: nil
  attr :user_tz, :string, required: true

  def grouped_list(assigns) do
    ~H"""
    <div
      class={[
        "space-y-6",
        "[--_top:var(--top,3rem)]",
        "sm:[--_top:var(--top,2rem)]"
      ]}
      data-testid="events-timeline"
    >
      <section
        :for={year_group <- @grouped_items}
        class="space-y-0"
        id={"events-year-#{year_group.year}"}
        data-testid={"events-year-#{year_group.year}"}
      >
        <h2
          class={[
            "text-xl font-semibold",
            "sticky z-[29] pt-4",
            @mask_class
          ]}
          style="top: var(--_top)"
        >
          {year_group.year}
        </h2>

        <section
          :for={month_group <- year_group.months}
          id={"events-month-#{year_group.year}-#{month_group.month}"}
          data-testid={"events-month-#{year_group.year}-#{month_group.month}"}
          class=""
        >
          <h3
            class={[
              "text-sm font-semibold uppercase tracking-wide text-base-content/80",
              "sticky z-[28]",
              @mask_class
            ]}
            style="top: calc(var(--_top) + 2.5rem)"
          >
            {month_group.label}
          </h3>

          <section
            :for={day_group <- month_group.days}
            class="space-y-3 pt-3"
            id={"events-day-#{year_group.year}-#{month_group.month}-#{day_group.day}"}
            data-testid={"events-day-#{year_group.year}-#{month_group.month}-#{day_group.day}"}
          >
            <h4
              class={[
                "text-sm font-medium tracking-wide text-base-content/70",
                "sticky z-[27]",
                "pb-2",
                @mask_class
              ]}
              style="top: calc(var(--_top) + 2.5rem + 1rem)"
            >
              {day_group.label}
            </h4>

            <div class="grid gap-4 mb-8">
              <article
                :for={item <- day_group.items}
                id={timeline_dom_id(item)}
                data-testid={timeline_testid(item)}
              >
                <%= if item.source_type == :internal do %>
                  <div
                    class={[
                      "bg-base-content/3",
                      item.participations != [] &&
                        [
                          "border-l border-[oklch(63%_0.13_358)] bg-base-content/3"
                        ]
                    ]}
                    data-state={if(item.participations == [], do: "ghost", else: "promoted")}
                  >
                    <.link
                      patch={item.open_path}
                      class={[
                        "block p-4",
                        "hover:bg-base-content/10",
                        "transition",
                        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/40"
                      ]}
                      data-testid={"event-open-#{item.publication.id}"}
                    >
                      <.timeline_item_body
                        current_scope={@current_scope}
                        grouped_date={Date.new!(year_group.year, month_group.month, day_group.day)}
                        item={item}
                        source_label_mode={@source_label_mode}
                        user_tz={@user_tz}
                      />
                    </.link>
                  </div>
                <% else %>
                  <div
                    class={[
                      item.participations == [] &&
                        [
                          "border-l-[1.7px] border-dashed border-base-content/35 rounded",
                          "bg-base-content/3",
                          "opacity-50 hover:opacity-100 transition"
                        ],
                      item.participations != [] &&
                        [
                          "border-l border-[oklch(63%_0.13_358)] bg-base-content/3"
                        ]
                    ]}
                    data-state={if(item.participations == [], do: "ghost", else: "promoted")}
                  >
                    <.link
                      patch={item.open_path}
                      class={[
                        "cursor-pointer",
                        "block px-4 py-2 pr-2",
                        "w-full",
                        "text-left",
                        item.participations != [] &&
                          [
                            "hover:bg-base-content/10",
                            "transition",
                            "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/40"
                          ]
                      ]}
                      data-testid={"event-open-#{item.id}"}
                    >
                      <.timeline_item_body
                        current_scope={@current_scope}
                        grouped_date={Date.new!(year_group.year, month_group.month, day_group.day)}
                        item={item}
                        source_label_mode={@source_label_mode}
                        user_tz={@user_tz}
                      />
                    </.link>
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

  attr :current_scope, :map, required: true
  attr :grouped_date, :any, default: nil
  attr :item, :map, required: true
  attr :source_label_mode, :atom, required: true
  attr :user_tz, :string, required: true

  defp timeline_item_body(assigns) do
    ~H"""
    <div class="min-w-0 space-y-1">
      <.timeline_item_body_head
        current_scope={@current_scope}
        item={@item}
        source_label_mode={@source_label_mode}
      />

      <div class="truncate text-sm opacity-80" data-testid={timeline_schedule_testid(@item)}>
        <Event.schedule event={@item.event} grouped_date={@grouped_date} user_tz={@user_tz} />
      </div>

      <div class="grid sm:grid-cols-[1fr_auto] gap-2 mt-2">
        <section
          class="space-y-1 flex flex-wrap gap-2"
          data-testid={"timeline-event-topic-list-#{@item.id}"}
        >
          <.timeline_item_body_topics item={@item} />
        </section>

        <section :if={@item.participations != []} class="flex flex-wrap items-center gap-2">
          <.timeline_item_body_participations item={@item} />
        </section>
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

  attr :current_scope, :map, required: true
  attr :item, :map, required: true
  attr :source_label_mode, :atom, required: true

  defp timeline_item_body_head(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center gap-2 justify-between">
      <div>
        <.timeline_item_source
          current_scope={@current_scope}
          item={@item}
          source_label_mode={@source_label_mode}
        />

        <h2 class={[
          "text-base font-medium leading-tight",
          "space-y-2",
          @item.event.status == :cancelled && "line-through decoration-base-content"
        ]}>
          <div>{@item.event.title}</div>
        </h2>
      </div>

      <Event.event_status event={@item.event} />
    </div>
    """
  end

  attr :current_scope, :map, required: true
  attr :item, :map, required: true
  attr :source_label_mode, :atom, required: true

  defp timeline_item_source(%{source_label_mode: :aggregate} = assigns) do
    ~H"""
    <div
      :if={present?(@item.source_name)}
      class="mb-1 truncate text-xs opacity-60 flex items-center gap-1"
      data-testid={"home-event-source-#{@item.id}"}
    >
      {@item.source_name}
    </div>
    """
  end

  defp timeline_item_source(%{item: %{source_type: :external}} = assigns) do
    ~H"""
    <div
      :if={present?(@item.calendar_name)}
      class="mb-1 text-xs opacity-60 flex gap-1"
      data-testid={"external-event-calendar-name-#{@item.id}"}
    >
      <.icon name="hero-calendar-micro" class="opacity-60" />
      <span class="truncate">{@item.calendar_name}</span>
    </div>
    """
  end

  defp timeline_item_source(assigns) do
    ~H"""
    <div
      :if={@item.source_type == :internal and present?(@current_scope.tenant.name)}
      class="mb-1 text-xs opacity-60 flex gap-1"
      data-testid={"event-source-#{@item.id}"}
    >
      <UI.icon_app class="opacity-80" />
      {@current_scope.tenant.name}
    </div>
    """
  end

  attr :item, :map, required: true

  defp timeline_item_body_topics(assigns) do
    ~H"""
    <div
      :for={summary <- Map.get(@item, :topic_summaries, [])}
      class={[
        "flex gap-1 items-center",
        "badge bg-base-300",
        "text-xs font-bold",
        "opacity-60",
        "pr-3 pl-2"
      ]}
      data-testid={"timeline-event-topic-#{@item.id}-#{summary.tag.id}"}
      title={Map.get(summary, :automatic?, false) && "Detected from event text"}
    >
      <.icon
        name={
          if(Map.get(summary, :automatic?, false),
            do: "hero-sparkles-micro",
            else: "hero-tag-micro"
          )
        }
        class="size-3 opacity-50"
      />
      <div class="truncate text-xs">{summary.tag.name}</div>
      <span :if={Map.get(summary, :automatic?, false)} class="sr-only">
        Detected from event text
      </span>

      <%!-- <LevelMeter.render --%>
      <%!--   :if={summary.average_relevancy} --%>
      <%!--   dimension={topic_relevancy_dimension()} --%>
      <%!--   label={topic_relevancy_dimension().label} --%>
      <%!--   level={summary.average_relevancy} --%>
      <%!--   testid={"timeline-event-topic-#{@item.id}-relevancy-#{summary.tag.id}"} --%>
      <%!--   width_class="w-8" --%>
      <%!-- /> --%>
    </div>
    """
  end

  attr :item, :map, required: true

  defp timeline_item_body_participations(assigns) do
    ~H"""
    <div
      :for={participation <- @item.participations}
      class="flex items-center gap-2 btn btn-xs rounded-full bg-base-300/30"
      data-testid={"timeline-event-participation-#{participation.id}"}
    >
      <User.identity
        avatar_size="xs"
        class="text-xs opacity-70"
        link?={false}
        name?={false}
        membership={participation.membership}
      />

      <LevelMeter.render
        dimension={interest_dimension()}
        label="Interest"
        level={participation.interest}
        testid={"timeline-event-participation-interest-#{participation.id}"}
        width_class="w-10"
      />
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

  defp interest_dimension, do: Dimensions.get!("participation", "interest")

  defp dev?, do: Application.get_env(:wik, :show_external_event_debug_ids?, false)

  defp present?(value), do: value not in [nil, ""]
end
