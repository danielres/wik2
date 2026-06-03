defmodule WikWeb.Components.Event do
  import Iconify

  use Phoenix.Component
  use WikWeb, :html

  alias Wik.Accounts
  alias Wik.Events.ExternalCalendar
  alias Wik.Tags.Dimensions
  alias WikWeb.Components.Event.ExternalDetails
  alias WikWeb.Components.Event.Schedule
  alias WikWeb.Components.Event.Timeline
  alias WikWeb.Components.LevelMeter
  alias WikWeb.Components.LocationPicker
  alias WikWeb.Components.TimezonePicker
  alias WikWeb.Components.UI
  alias WikWeb.Components.User

  attr :form, Phoenix.HTML.Form, required: true
  attr :show_end_date?, :boolean, default: false
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
        <.input field={@form[:title]} label="Title" phx-hook="CapitalizeFirstLetter" />

        <div class="grid gap-3 sm:grid-cols-2">
          <.input
            field={@form[:starts_on]}
            errors={if @all_day?, do: schedule_errors_for(@form, :starts_at), else: []}
            id="event-starts-on"
            label="Start date"
            type="date"
          />
          <div class="fieldset">
            <label>
              <div class="group label cursor-pointer flex items-center gap-2">
                <button
                  :if={@show_end_date?}
                  type="button"
                  class="cursor-pointer opacity-50 group-hover:opacity-100 group-hover:text-error transition -mt-0.5"
                  data-testid="event-form-end-date-remove"
                  phx-click="event_form_end_date_remove"
                  phx-target={@target}
                >
                  <.icon name="hero-x-circle-micro" />
                </button>

                <button
                  :if={not @show_end_date?}
                  type="button"
                  class="cursor-pointer opacity-50 group-hover:opacity-100 group-hover:text-accent transition -mt-0.5"
                  data-testid="event-form-end-date-add"
                  phx-click="event_form_end_date_add"
                  phx-target={@target}
                >
                  <.icon name="hero-plus-circle-micro" />
                </button>

                <span class="group-hover:text-base-content/80 transition">End date</span>
              </div>

              <.input
                :if={@show_end_date? and false}
                field={@form[:ends_on]}
                errors={if @all_day?, do: schedule_errors_for(@form, :ends_at), else: []}
                id="event-ends-on"
                type="date"
              />

              <input
                :if={@show_end_date?}
                type="date"
                name="form[ends_on]"
                id="event-ends-on"
                value={Phoenix.HTML.Form.input_value(@form, :ends_on)}
                class={[
                  "w-full input",
                  end_date_errors_for(@form, @all_day?) != [] && "input-error"
                ]}
              />
            </label>
            <.error :for={msg <- end_date_errors_for(@form, @all_day?)}>{msg}</.error>
          </div>
        </div>

        <.input field={@form[:all_day]} label="All-day event" type="checkbox" />

        <div :if={not @all_day?} class="grid gap-3 sm:grid-cols-2">
          <.input
            field={@form[:starts_at_time]}
            errors={if @all_day?, do: [], else: schedule_errors_for(@form, :starts_at)}
            id="event-starts-at-time"
            label="Start time"
            type="time"
          />

          <.input
            field={@form[:ends_at_time]}
            errors={if @all_day?, do: [], else: schedule_errors_for(@form, :ends_at)}
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

        <.input
          field={@form[:relay_policy]}
          label="Relay policy"
          type="select"
          options={relay_policy_options()}
        />

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

  attr :form, Phoenix.HTML.Form, required: true
  attr :target, :any, default: nil

  def converted_layer_form(assigns) do
    ~H"""
    <.form
      for={@form}
      id="converted-layer-form"
      data-testid="converted-layer-form"
      phx-submit="converted_layer_submit"
      phx-target={@target}
    >
      <div class="space-y-4">
        <.input field={@form[:title]} label="Local title" />
        <.input field={@form[:description]} label="Local info" type="textarea" />

        <div class="flex justify-end gap-2">
          <button
            type="button"
            class="btn btn-ghost btn-sm"
            data-testid="converted-layer-cancel"
            phx-click="converted_layer_cancel"
            phx-target={@target}
          >
            Cancel
          </button>

          <button type="submit" class="btn btn-accent btn-sm" data-testid="converted-layer-submit">
            Save
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

  defp schedule_errors_for(form, field) do
    if schedule_used?(form) do
      errors_for(form, field)
    else
      []
    end
  end

  defp end_date_errors_for(form, true), do: schedule_errors_for(form, :ends_at)
  defp end_date_errors_for(_form, false), do: []

  defp schedule_used?(form) do
    form.source.just_submitted? ||
      Phoenix.Component.used_input?(form[:starts_on]) ||
      Phoenix.Component.used_input?(form[:starts_at_time]) ||
      Phoenix.Component.used_input?(form[:ends_on]) ||
      Phoenix.Component.used_input?(form[:ends_at_time])
  end

  defp google_maps_search_url(location) do
    "https://www.google.com/maps/search/?" <>
      URI.encode_query(%{api: 1, query: location})
  end

  attr :publication, :map, required: true

  def event_header(assigns) do
    assigns = assign(assigns, :event, display_event(assigns.publication.event))

    ~H"""
    <h2 class={[
      "text-base font-medium leading-tight",
      "flex-grow",
      "flex items-center gap-2",
      @event.status == :cancelled && "line-through decoration-base-content"
    ]}>
      <.iconify
        :if={@publication.publication_type == :relay}
        icon="mdi:share"
        class="text-base-content/30 size-5 -ml-5 absolute"
      />
      {@event.title}
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
  attr :author_membership, :map, default: nil
  attr :current_member_participation, :any, default: nil
  attr :participations, :list, default: []
  attr :relayer_membership, :map, default: nil
  attr :show_origin_space?, :boolean, default: false
  attr :target, :any, default: nil
  attr :user_tz, :string, required: true

  def event_details(assigns) do
    assigns =
      assign(
        assigns,
        :author,
        Accounts.present_membership(assigns.author_membership)
      )
      |> assign(:relayer, Accounts.present_membership(assigns.relayer_membership))
      |> assign(:display_event, display_event(assigns.publication.event))
      |> assign(:source_external_event, assigns.publication.event.source_external_event)
      |> assign(
        :source_external_item,
        source_external_item(assigns.publication.event.source_external_event)
      )

    ~H"""
    <div class="space-y-5" data-testid="event-detail">
      <div class="float-right flex flex-col items-start gap-2">
        <UI.button_edit
          :if={@can_edit?}
          data-testid={"event-detail-edit-#{@publication.id}"}
          phx-click="event_detail_edit_start"
          phx-value-publication_id={@publication.id}
          phx-target={@target}
        />

        <UI.button_relay
          :if={@can_relay?}
          data-testid={"event-detail-relay-#{@publication.id}"}
          phx-click="event_detail_relay_start"
          phx-target={@target}
          phx-value-publication_id={@publication.id}
        />
      </div>

      <div class="">
        <div class="flex justify-between gap-2 mb-4">
          <.event_header publication={@publication} />
          <.event_status event={@display_event} />
        </div>

        <div class="grid grid-cols-[1fr_auto] gap-4">
          <div>
            <.schedule
              class="text-sm opacity-70"
              event={@display_event}
              user_tz={@user_tz}
            />
          </div>
        </div>
      </div>

      <div :if={@display_event.location not in [nil, ""]} class="flex gap-2 items-start">
        <.icon name="hero-map-pin-mini" class="mt-0.5" />
        <div class="min-w-0">
          <div class="text-sm">{@display_event.location}</div>
          <.link
            class="link link-hover text-xs opacity-70"
            data-testid="event-location-google-maps-link"
            href={google_maps_search_url(@display_event.location)}
            rel="noopener noreferrer"
            target="_blank"
          >
            Open in Google Maps
          </.link>
        </div>
      </div>

      <div :if={@publication.event.description not in [nil, ""]}>
        <div class="text-xs uppercase tracking-wide opacity-50">
          Local info
        </div>

        <div class={[
          "text-sm leading-6",
          "rounded-md bg-base-content/5 px-4 py-2"
        ]}>
          <div class="whitespace-pre-wrap">{@publication.event.description}</div>
        </div>
      </div>

      <div>
        <button
          type="button"
          class="btn btn-sm btn-ghost"
          data-testid={"event-detail-interest-#{@publication.id}"}
          phx-click="event_interest_start"
          phx-value-id={@publication.id}
          phx-value-source_type="internal"
        >
          {if @current_member_participation, do: "Edit interest", else: "Add interest"}
        </button>
      </div>

      <div :if={@participations != []} class="space-y-2">
        <div class="text-xs uppercase tracking-wide opacity-50">
          Interest
        </div>

        <div
          :for={participation <- @participations}
          class="flex items-center gap-2 text-sm"
          data-testid={"event-participation-#{participation.id}"}
        >
          <User.identity
            avatar_size="xs"
            class="text-xs opacity-70"
            membership={participation.membership}
          />
          <LevelMeter.render
            dimension={interest_dimension()}
            label="Interest"
            level={participation.interest}
            testid={"event-participation-interest-#{participation.id}"}
            width_class="w-16"
          />
          <div :if={participation.extra_info not in [nil, ""]} class="opacity-70">
            {participation.extra_info}
          </div>
        </div>
      </div>

      <div :if={@source_external_event} class="space-y-2">
        <div class="text-xs uppercase tracking-wide opacity-50">
          Original event
        </div>

        <div :if={@source_external_event.source_missing_at} class="text-sm text-warning">
          No longer found in external calendar.
        </div>

        <div class={[
          "rounded-box",
          "p-2",
          "opacity-70 hover:opacity-100 transition-opacity",
          "border-[1.5px] border-dashed border-base-content/30"
        ]}>
          <ExternalDetails.render item={@source_external_item} user_tz={@user_tz} />
        </div>
      </div>

      <div class="space-y-1">
        <div class="text-xs uppercase tracking-wide opacity-50">
          By
        </div>
        <User.identity
          avatar_size="xs"
          class="text-xs opacity-60"
          link?={true}
          membership={@author}
        />
      </div>

      <div
        :if={
          @publication.publication_type == :relay and
            (@show_origin_space? or @publication.relay_note not in [nil, ""])
        }
        class="space-y-6"
      >
        <div :if={@show_origin_space?}>
          <div class="text-xs uppercase tracking-wide opacity-50">
            Relayed from
          </div>

          <.link
            :if={@show_origin_space?}
            navigate={
              ~p"/#{@publication.event.space.slug}/events?external=false&event=#{@publication.event.id}"
            }
            class="badge badge-soft badge-sm"
          >
            {@publication.event.space.name}
          </.link>
        </div>

        <div :if={
          @publication.publication_type == :relay and @publication.relay_note not in [nil, ""]
        }>
          <div class="text-xs uppercase tracking-wide opacity-50">
            Extra notes by {@relayer.display_name}
          </div>

          <div class={[
            "text-sm leading-6",
            "mt-1",
            "rounded-md bg-base-content/5 px-4 py-2"
          ]}>
            {@publication.relay_note}
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp display_event(%{source_external_event: %{id: _id} = external_event} = local_event) do
    %{external_event | title: local_event.title || external_event.title}
  end

  defp display_event(event), do: event

  defp interest_dimension, do: Dimensions.get!("membership", "interest")

  defp source_external_item(nil), do: nil

  defp source_external_item(external_event) do
    %{
      event: external_event,
      event_url: external_event.event_url,
      external_uid: external_event.external_uid,
      external_recurrence_id: external_event.external_recurrence_id,
      calendar_name: source_external_calendar_name(external_event)
    }
  end

  defp source_external_calendar_name(%{subscription: %Ash.NotLoaded{}} = external_event) do
    external_event.calendar_name
  end

  defp source_external_calendar_name(%{subscription: subscription} = external_event)
       when not is_nil(subscription) do
    ExternalCalendar.display_name(subscription, external_event.calendar_name)
  end

  defp source_external_calendar_name(external_event), do: external_event.calendar_name

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
            label="Extra notes"
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

  attr :current_scope, :map, default: nil
  attr :items, :list, default: []
  attr :grouped_items, :list, default: []
  attr :load_more_path, :string, default: nil
  attr :show_external?, :boolean, default: false
  attr :target, :any, default: nil
  attr :user_tz, :string, required: true

  def list(assigns), do: Timeline.compact_list(assigns)
  def grouped_timeline(assigns), do: Timeline.grouped_list(assigns)

  attr :class, :string, default: nil
  attr :event, :map, required: true
  attr :grouped_date, :any, default: nil
  attr :user_tz, :string, required: true

  def schedule(assigns), do: Schedule.render(assigns)

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
      {"Only admins can relay to other spaces", "admins_only_spaces"},
      {"All members can relay to other spaces", "members_to_spaces"}
    ]
  end
end
