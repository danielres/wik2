defmodule WikWeb.Components.Event do
  import Iconify

  use Phoenix.Component
  use WikWeb, :html

  alias Utils.Tz
  alias WikWeb.Components.LocationPicker
  alias WikWeb.Components.TimezonePicker

  attr :form, Phoenix.HTML.Form, required: true
  attr :target, :any, default: nil
  attr :user_tz, :string, required: true

  def event_form(assigns) do
    all_day? = Phoenix.HTML.Form.input_value(assigns.form, :all_day)
    assigns = assign(assigns, :all_day?, all_day?)

    ~H"""
    <.form
      for={@form}
      id="event-form"
      data-testid="event-form"
      phx-change="event_form_validate"
      phx-submit="event_form_submit"
      phx-target={@target}
    >
      <div class="space-y-3">
        <.input field={@form[:title]} label="Title" />

        <div class="grid gap-3 sm:grid-cols-2">
          <.input
            field={@form[:starts_on]}
            errors={if @all_day?, do: errors_for(@form, :starts_at), else: []}
            id="event-starts-on"
            label="Start date"
            type="date"
          />

          <.input
            field={@form[:ends_on]}
            errors={if @all_day?, do: errors_for(@form, :ends_at), else: []}
            id="event-ends-on"
            label="End date"
            type="date"
          />
        </div>

        <.input field={@form[:all_day]} label="All-day event" type="checkbox" />

        <div :if={not @all_day?} class="grid gap-3 sm:grid-cols-2">
          <.input
            field={@form[:starts_at_time]}
            errors={if @all_day?, do: [], else: errors_for(@form, :starts_at)}
            id="event-starts-at-time"
            label="Start time"
            type="time"
          />

          <.input
            field={@form[:ends_at_time]}
            errors={if @all_day?, do: [], else: errors_for(@form, :ends_at)}
            id="event-ends-at-time"
            label="End time"
            type="time"
          />
        </div>

        <TimezonePicker.field
          field={@form[:tz]}
          id="event-tz-picker"
          label="Event timezone"
          suggested_values={[@user_tz]}
          testid="event-tz-picker"
        />

        <LocationPicker.field
          field={@form[:location]}
          id="event-location-picker"
          label="Location"
          testid="event-location-picker"
        />

        <.input field={@form[:description]} label="Description" type="textarea" />

        <div class={[
          "grid gap-3 sm:grid-cols-2",
          "bg-base-200 px-4 py-2 rounded-box",
          "my-8"
        ]}>
          <.input
            field={@form[:relay_policy]}
            label="Relay policy"
            type="select"
            options={relay_policy_options()}
          />

          <.input
            field={@form[:provenance_policy]}
            label="Provenance"
            type="select"
            options={provenance_policy_options()}
          />
        </div>

        <.input
          :if={@form.source.type == :update}
          field={@form[:status]}
          label="Status"
          type="select"
          options={status_options()}
        />

        <div class="flex justify-end gap-2 pt-2">
          <button
            type="button"
            class="btn btn-ghost btn-sm"
            data-testid="event-form-dismiss"
            phx-click="event_form_cancel"
            phx-target={@target}
          >
            Close
          </button>

          <button
            type="submit"
            class="btn btn-accent btn-sm"
            data-testid="event-form-submit"
          >
            {if @form.source.type == :create, do: "Create event", else: "Save changes"}
          </button>
        </div>
      </div>
    </.form>
    """
  end

  defp errors_for(form, field) do
    form[field].errors
    |> Enum.map(&WikWeb.CoreComponents.translate_error/1)
  end

  defp google_maps_search_url(location) do
    "https://www.google.com/maps/search/?" <>
      URI.encode_query(%{api: 1, query: location})
  end

  attr :publication, :map, required: true

  def event_header(assigns) do
    ~H"""
    <h2 class={[
      "truncate text-base font-medium leading-tight",
      "flex-grow",
      "flex items-center gap-2",
      @publication.event.status == :cancelled && "line-through decoration-base-content"
    ]}>
      <.iconify
        :if={@publication.publication_type == :relay}
        icon="mdi:share"
        class="text-base-content/30 size-5 -ml-5 absolute"
      />
      {@publication.event.title}
    </h2>
    """
  end

  attr :event, :map, required: true

  def event_status(assigns) do
    ~H"""
    <span
      :if={@event.status != :published}
      class={[
        "badge badge-sm",
        @event.status == :cancelled && "bg-error/50 text-error-content"
      ]}
    >
      {@event.status}
    </span>
    """
  end

  attr :can_edit?, :boolean, required: true
  attr :can_relay?, :boolean, required: true
  attr :publication, :map, required: true
  attr :target, :any, default: nil
  attr :user_tz, :string, required: true

  def event_details(assigns) do
    ~H"""
    <div class="space-y-5" data-testid="event-detail">
      <div class="float-right flex flex-col items-start gap-1">
        <button
          :if={@can_edit?}
          class={["btn btn-sm btn-circle btn-accent"]}
          data-testid={"event-detail-edit-#{@publication.id}"}
          phx-click="event_detail_edit_start"
          phx-value-publication_id={@publication.id}
          phx-target={@target}
        >
          <.icon name="hero-pencil-square-micro" class="size-4" />
        </button>
        <button
          :if={@can_relay?}
          aria-label="Relay event"
          title="Relay event"
          class={["btn btn-sm btn-circle btn-accent"]}
          data-testid={"event-detail-relay-#{@publication.id}"}
          phx-click="event_detail_relay_start"
          phx-target={@target}
          phx-value-publication_id={@publication.id}
        >
          <.iconify icon="mdi:share" class="size-5" />
        </button>
      </div>

      <div class="">
        <div class="flex justify-between gap-2 mb-4">
          <.event_header publication={@publication} />
          <.event_status event={@publication.event} />
        </div>

        <div class="grid grid-cols-[1fr_auto] gap-4">
          <div>
            <.schedule
              class="text-sm opacity-70"
              event={@publication.event}
              user_tz={@user_tz}
            />
          </div>
        </div>
      </div>

      <div :if={@publication.event.location not in [nil, ""]} class="flex gap-2 items-start">
        <.icon name="hero-map-pin-mini" class="mt-0.5" />
        <div class="min-w-0">
          <div class="text-sm">{@publication.event.location}</div>
          <.link
            class="link link-hover text-xs opacity-70"
            data-testid="event-location-google-maps-link"
            href={google_maps_search_url(@publication.event.location)}
            rel="noopener noreferrer"
            target="_blank"
          >
            Open in Google Maps
          </.link>
        </div>
      </div>

      <div>
        <div class="text-xs uppercase tracking-wide opacity-50">
          Description
        </div>

        <div class={[
          "text-sm leading-6",
          "border border-base-300 rounded-md bg-base-content/5 px-4 py-2"
        ]}>
          <div class="whitespace-pre-wrap">{@publication.event.description}</div>
        </div>
      </div>

      <div :if={@publication.event.provenance_policy == :visible}>
        <div class="text-xs uppercase tracking-wide opacity-50">
          Context
        </div>

        <div class={[
          ""
        ]}>
          <span class="badge badge-soft">by {@publication.event.author |> to_string()}</span>
          <span :if={@publication.publication_type == :origin} class="badge badge-soft">
            in {@publication.event.space.name}
          </span>
          <span :if={@publication.publication_type == :relay} class="badge badge-soft">
            from {@publication.event.space.name}
          </span>
          <span :if={@publication.publication_type == :relay} class="badge badge-soft">
            relayed by {@publication.published_by |> to_string()}
          </span>
        </div>

        <p
          :if={@publication.publication_type == :relay and @publication.relay_note not in [nil, ""]}
          class="mt-3 text-sm opacity-70"
        >
          {@publication.relay_note}
        </p>
      </div>
    </div>
    """
  end

  attr :publication, :map, required: true
  attr :relay_error, :string, default: nil
  attr :relay_form, Phoenix.HTML.Form, required: true
  attr :relay_target_spaces, :list, required: true
  attr :target, :any, default: nil

  def relay_form(assigns) do
    ~H"""
    <div class="space-y-5" data-testid="event-relay">
      <div class="space-y-1">
        <div class="text-xs uppercase tracking-wide opacity-50">
          Relay event
        </div>

        <h2 class="text-base font-medium leading-tight">
          {@publication.event.title}
        </h2>
      </div>

      <p
        :if={@relay_error not in [nil, ""]}
        class="text-sm text-error"
        data-testid="event-relay-error"
      >
        {@relay_error}
      </p>

      <div
        :if={@relay_target_spaces == [] and @relay_error in [nil, ""]}
        class="text-sm opacity-70"
        data-testid="event-relay-empty"
      >
        No spaces available to relay to.
      </div>

      <.form
        :if={@relay_target_spaces != []}
        for={@relay_form}
        id="event-relay-form"
        data-testid="event-relay-form"
        phx-submit="event_relay_submit"
        phx-target={@target}
      >
        <div class="space-y-4">
          <.input
            field={@relay_form[:target_space_id]}
            id="event-relay-target-space-id"
            label="Target space"
            options={Enum.map(@relay_target_spaces, &{&1.name, &1.id})}
            prompt="Select a space"
            type="select"
          />

          <.input
            field={@relay_form[:relay_note]}
            id="event-relay-note"
            label="Relay note"
            type="textarea"
          />

          <div class="flex justify-end gap-2 pt-2">
            <button
              type="button"
              class="btn btn-ghost btn-sm"
              data-testid="event-relay-cancel"
              phx-click="event_relay_cancel"
              phx-target={@target}
            >
              Back
            </button>

            <button
              type="submit"
              class="btn btn-accent btn-sm"
              data-testid="event-relay-submit"
            >
              Relay
            </button>
          </div>
        </div>
      </.form>

      <div :if={@relay_target_spaces == []} class="flex justify-end pt-2">
        <button
          type="button"
          class="btn btn-ghost btn-sm"
          data-testid="event-relay-cancel"
          phx-click="event_relay_cancel"
          phx-target={@target}
        >
          Back
        </button>
      </div>
    </div>
    """
  end

  attr :current_scope, :map, required: true
  attr :event_publications, :list, required: true
  attr :user_tz, :string, required: true

  def list(assigns) do
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
        class={[
          "rounded-box bg-base-200 p-0 transition overflow-hidden"
        ]}
      >
        <.link
          patch={event_link_target(@current_scope, publication)}
          class={[
            "block p-4 hover:bg-base-300/70 transition",
            "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/40"
          ]}
          data-testid={"event-open-#{publication.id}"}
        >
          <div class="min-w-0 space-y-1">
            <div class="flex flex-wrap items-center gap-2">
              <.event_header publication={publication} />
              <.event_status event={publication.event} />
            </div>

            <div
              class="truncate text-sm opacity-80"
              data-testid={"event-schedule-#{publication.id}"}
            >
              <.schedule
                event={publication.event}
                user_tz={@user_tz}
              />
            </div>
          </div>
        </.link>
      </article>
    </div>
    """
  end

  defp event_link_target(%{tenant: %{slug: space_slug}}, publication) do
    ~p"/#{space_slug}/events?#{%{event: publication.id}}"
  end

  defp event_link_target(_scope, publication) do
    ~p"/#{publication.space.slug}/events?#{%{event: publication.id}}"
  end

  attr :class, :string, default: nil
  attr :event, :map, required: true
  attr :user_tz, :string, required: true

  def schedule(assigns) do
    assigns =
      assigns
      |> assign(:event_parts, schedule_parts(assigns.event, assigns.event.tz))
      |> assign(:show_user_tz?, assigns.user_tz != assigns.event.tz)
      |> assign(:user_parts, schedule_parts(assigns.event, assigns.user_tz))

    ~H"""
    <div class={["space-y-1", @class]}>
      <.schedule_row parts={@event_parts} tz={@event.tz} />
      <.schedule_row :if={@show_user_tz?} parts={@user_parts} tz={@user_tz} secondary? />
    </div>
    """
  end

  attr :parts, :map, required: true
  attr :tz, :string, required: true
  attr :secondary?, :boolean, default: false

  defp schedule_row(%{parts: %{kind: :timed, same_day?: true}} = assigns) do
    ~H"""
    <div class={["flex flex-wrap items-center gap-x-1 gap-y-1", @secondary? && "opacity-75 text-xs"]}>
      <span class="font-medium">{@parts.start_date}</span>
      <span>{@parts.start_time}</span>
      <span class="mx-1 opacity-50">to</span>
      <span>{@parts.end_time}</span>
      <span class="badge badge-sm bg-base-300">{@tz}</span>
    </div>
    """
  end

  defp schedule_row(%{parts: %{kind: :timed, same_day?: false}} = assigns) do
    ~H"""
    <div class={["flex flex-wrap items-center gap-x-1 gap-y-1", @secondary? && "opacity-75 text-xs"]}>
      <span class="font-medium">{@parts.start_date}</span>
      <span>{@parts.start_time}</span>
      <span class="mx-1 opacity-50">to</span>
      <span class="font-medium">{@parts.end_date}</span>
      <span>{@parts.end_time}</span>
      <span class="badge badge-sm bg-base-300">{@tz}</span>
    </div>
    """
  end

  defp schedule_row(%{parts: %{kind: :all_day_single}} = assigns) do
    ~H"""
    <div class={["flex flex-wrap items-center gap-x-1 gap-y-1", @secondary? && "opacity-75 text-xs"]}>
      <span class="font-medium">{@parts.start_date}</span>
      <span class="badge badge-sm bg-base-300">{@tz}</span>
    </div>
    """
  end

  defp schedule_row(%{parts: %{kind: :all_day_range}} = assigns) do
    ~H"""
    <div class={["flex flex-wrap items-center gap-x-1 gap-y-1", @secondary? && "opacity-75 text-xs"]}>
      <span class="font-medium">{@parts.start_date}</span>
      <span class="mx-1 opacity-50">to</span>
      <span class="font-medium">{@parts.end_date}</span>
      <span class="badge badge-sm bg-base-300">{@tz}</span>
    </div>
    """
  end

  defp schedule_parts(event, tz) do
    if event.all_day do
      all_day_schedule_parts(event, tz)
    else
      timed_schedule_parts(event, tz)
    end
  end

  defp timed_schedule_parts(event, tz) do
    starts_at = Tz.to_local!(event.starts_at, tz)
    ends_at = Tz.to_local!(event.ends_at, tz)

    %{
      kind: :timed,
      same_day?: Date.compare(DateTime.to_date(starts_at), DateTime.to_date(ends_at)) == :eq,
      start_date: Calendar.strftime(starts_at, "%Y-%m-%d"),
      start_time: Calendar.strftime(starts_at, "%H:%M"),
      end_date: Calendar.strftime(ends_at, "%Y-%m-%d"),
      end_time: Calendar.strftime(ends_at, "%H:%M")
    }
  end

  defp all_day_schedule_parts(event, tz) do
    start_date = event.starts_at |> Tz.to_local!(tz) |> DateTime.to_date()

    end_date =
      case event.ends_at do
        nil -> nil
        ends_at -> ends_at |> Tz.to_local!(tz) |> DateTime.to_date()
      end

    if is_nil(end_date) or Date.compare(start_date, end_date) == :eq do
      %{
        kind: :all_day_single,
        start_date: Calendar.strftime(start_date, "%Y-%m-%d")
      }
    else
      %{
        kind: :all_day_range,
        start_date: Calendar.strftime(start_date, "%Y-%m-%d"),
        end_date: Calendar.strftime(end_date, "%Y-%m-%d")
      }
    end
  end

  defp provenance_policy_options do
    [
      {"Show origin and relay context", "visible"},
      {"Hide origin and relay context", "hidden"}
    ]
  end

  defp status_options do
    [
      {"Draft", "draft"},
      {"Published", "published"},
      {"Cancelled", "cancelled"}
    ]
  end

  defp relay_policy_options do
    [
      {"Internal only", "internal_only"},
      {"Admins can relay to spaces", "admins_only_spaces"},
      {"Members can relay to spaces", "members_to_spaces"}
    ]
  end
end
