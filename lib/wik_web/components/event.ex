defmodule WikWeb.Components.Event do
  import Iconify

  use Phoenix.Component
  use WikWeb, :html

  alias Wik.Accounts
  alias Wik.Events.Dimensions
  alias WikWeb.Components.RangeInput
  alias WikWeb.Components.Event.Schedule
  alias WikWeb.Components.Event.Timeline
  alias WikWeb.Components.LevelMeter
  alias WikWeb.Components.LocationPicker
  alias WikWeb.Components.TimezonePicker
  alias WikWeb.Components.UI
  alias WikWeb.Components.User

  attr :form, Phoenix.HTML.Form, required: true
  attr :interest_form, Phoenix.HTML.Form, default: nil
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

        <div class={[
          "border border-base-content/20 bg-base-content/3 rounded p-4",
          "mt-4"
        ]}>
          <.interest_fields :if={@interest_form} form={@interest_form} />
        </div>

        <div class={[
          "border border-base-content/20 bg-base-content/3 rounded p-4"
        ]}>
          <.input
            field={@form[:status]}
            label="Status"
            type="select"
            options={status_options()}
          />

          <.input
            field={@form[:relay_policy]}
            label="Relay policy"
            type="select"
            options={relay_policy_options()}
          />
        </div>

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

  def interest_fields(assigns) do
    assigns = assign(assigns, :interest_dimension, interest_dimension())

    ~H"""
    <div class="space-y-4">
      <RangeInput.render
        field={@form[:interest]}
        dimension={@interest_dimension}
        label="How likely are you to join?"
        max_level={@interest_dimension.max}
      />

      <.input
        field={@form[:extra_info]}
        id="event-interest-extra-info"
        label="Extra info"
        placeholder="For example: I'm planning to join around 15:00"
        phx-hook="CapitalizeFirstLetter"
        type="text"
      />
    </div>
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
    ~H"""
    <h2 class={[
      "text-base font-medium leading-tight",
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
        @event.status == :cancelled && "bg-error/80 text-error-content"
      ]}
    >
      {@event.status}
    </span>
    """
  end

  attr :author_membership, :map, default: nil
  attr :can_edit?, :boolean, required: true
  attr :can_relay?, :boolean, required: true
  attr :current_member_participation, :any, default: nil
  attr :current_membership, :map, required: true
  attr :participations, :list, default: []
  attr :publication, :map, required: true
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
      |> assign(:display_event, assigns.publication.event)

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
            class="link link-hover text-xs opacity-70 flex items-center gap-0"
            data-testid="event-location-google-maps-link"
            href={google_maps_search_url(@display_event.location)}
            rel="noopener noreferrer"
            target="_blank"
          >
            <span>Open in Google Maps</span>
            <.icon name="hero-arrow-top-right-on-square-micro" class="scale-80" />
          </.link>
        </div>
      </div>

      <WikWeb.Components.Event.Panel.render title="Participation">
        <div
          :if={!@current_member_participation}
          class={[
            "rounded-md bg-base-content/5 px-2 py-1",
            "mb-2"
          ]}
        >
          <div class={["flex justify-between"]}>
            <User.identity
              avatar_size="xs"
              class="text-xs opacity-70"
              membership={@current_membership}
            />

            <button
              type="button"
              class="btn btn-xs transition btn-neutral btn-soft"
              data-testid={"event-detail-interest-#{@publication.id}"}
              phx-click="event_interest_start"
              phx-value-id={@publication.id}
              phx-value-source_type="internal"
              style={"color: #{interest_dimension().color}"}
            >
              <span>Add</span>
              <.icon
                name="hero-plus-circle-micro"
                class="scale-80"
                style={"color: #{interest_dimension().color}"}
              />
            </button>
          </div>
        </div>

        <div
          :for={participation <- @participations}
          data-testid={"event-participation-#{participation.id}"}
          class={[
            "rounded-md bg-base-content/5 px-2 py-1"
          ]}
        >
          <div class={[
            "flex justify-between"
          ]}>
            <User.identity
              avatar_size="xs"
              class="text-xs opacity-70"
              membership={participation.membership}
            />

            <div class="flex gap-1 items-center">
              <LevelMeter.render
                :if={
                  !@current_member_participation ||
                    participation.membership_id != @current_member_participation.membership_id
                }
                dimension={interest_dimension()}
                label="Interest"
                level={participation.interest}
                testid={"event-participation-interest-#{participation.id}"}
                width_class="w-10"
                class="ml-auto mr-2"
              />

              <button
                :if={
                  @current_member_participation &&
                    participation.membership_id == @current_member_participation.membership_id
                }
                type="button"
                class={["btn btn-ghost btn-xs hover:btn-soft rounded-full"]}
                data-testid={"event-detail-interest-#{@publication.id}"}
                phx-click="event_interest_start"
                phx-value-id={@publication.id}
                phx-value-source_type="internal"
              >
                <.icon
                  name="hero-pencil-micro"
                  style={"color: #{interest_dimension().color}"}
                />
                <LevelMeter.render
                  dimension={interest_dimension()}
                  label="Interest"
                  level={participation.interest}
                  testid={"event-participation-interest-#{participation.id}"}
                  width_class="w-10"
                  class="ml-auto"
                />
              </button>
            </div>
          </div>
          <div :if={participation.extra_info not in [nil, ""]} class="opacity-70 text-xs ml-5">
            {participation.extra_info}
          </div>
        </div>
      </WikWeb.Components.Event.Panel.render>

      <WikWeb.Components.Event.Panel.render
        :if={@publication.event.description not in [nil, ""]}
        title="Description"
      >
        <div class={[
          "rounded-md bg-base-content/5 px-4 py-2 text-base-content/90",
          "text-xs leading-6"
        ]}>
          <div class="whitespace-pre-wrap">{@publication.event.description}</div>
        </div>
      </WikWeb.Components.Event.Panel.render>

      <WikWeb.Components.Event.Panel.render title="By">
        <User.identity
          avatar_size="xs"
          class="text-xs opacity-60"
          link?={true}
          membership={@author}
        />
      </WikWeb.Components.Event.Panel.render>

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

  defp interest_dimension, do: Dimensions.get!("participation", "interest")

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
