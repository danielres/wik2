defmodule WikWeb.EventsLiveTest do
  use WikWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Accounts.Membership
  alias Wik.Events
  alias Wik.Events.Event
  alias Wik.Events.EventParticipation
  alias Wik.Events.EventPublication
  alias Wik.Events.ExternalCalendar
  alias Wik.Events.ExternalEvent
  alias Wik.Repo

  require Ash.Query

  setup do
    previous = Application.get_env(:wik, Wik.Locations, [])
    previous_external_calendar = Application.get_env(:wik, Wik.Events.ExternalCalendar, [])

    Application.put_env(:wik, Wik.Locations, api_url: "https://example.test/location")

    Application.put_env(:wik, Wik.Events.ExternalCalendar,
      http_get: fn _url, _opts ->
        {:ok, %Req.Response{status: 200, body: sample_ics_calendar()}}
      end
    )

    on_exit(fn ->
      Application.put_env(:wik, Wik.Locations, previous)
      Application.put_env(:wik, Wik.Events.ExternalCalendar, previous_external_calendar)
    end)

    :ok
  end

  test "space members can view the compact timeline and open event detail by query param", %{
    conn: conn
  } do
    owner = generate(user())
    member = generate(user())
    space = generate(space(author: owner))

    add_membership(space, owner, :owner)
    add_membership(space, member, :member)
    grant_active_telegram_access(space, member)

    {:ok, _event} =
      Ash.create(Event, event_attrs(title: "Shared dinner"),
        action: :create,
        scope: scope(owner, space)
      )

    [publication] =
      Ash.read!(
        Wik.Events.EventPublication,
        authorize?: false,
        scope: scope(owner, space)
      )

    {:ok, view, _html} =
      conn
      |> log_in(member)
      |> live(~p"/#{space.slug}/events")

    assert has_element?(view, testid("events-page"))
    assert has_element?(view, testid("event-publication-#{publication.id}"))
    refute render(view) =~ "An event description"
    refute has_element?(view, testid("events-create-button"))

    render_click(element(view, testid("event-open-#{publication.id}")))

    assert_patch(
      view,
      ~p"/#{space.slug}/events?#{%{event: publication.event_id, external: false}}"
    )

    assert has_element?(view, testid("event-detail"))
    assert render(view) =~ "An event description"
    assert render(view) =~ "Community Hall, 123 Example Street"

    assert has_element?(view, testid("event-location-google-maps-link"))
    assert render(view) =~ "https://www.google.com/maps/search/"
    assert render(view) =~ "Community+Hall%2C+123+Example+Street"
  end

  test "event details author links to the member profile", %{
    conn: conn
  } do
    owner = generate(user())
    member = generate(user())
    space = generate(space(author: owner))

    owner_membership = add_membership(space, owner, :owner)
    add_membership(space, member, :member)
    grant_active_telegram_access(space, member)

    set_username(owner_membership, "owner-ada")

    {:ok, _event} =
      Ash.create(Event, event_attrs(title: "Shared dinner"),
        action: :create,
        scope: scope(owner, space)
      )

    [publication] =
      Ash.read!(
        Wik.Events.EventPublication,
        authorize?: false,
        scope: scope(owner, space)
      )

    {:ok, view, _html} =
      conn
      |> log_in(member)
      |> live(~p"/#{space.slug}/events?#{%{event: publication.event_id, external: false}}")

    assert has_element?(view, ~s(a[href="/#{space.slug}/wiki/members/owner-ada"]))
  end

  test "relay button appears only when there is an eligible target space", %{conn: conn} do
    owner = generate(user())
    target_owner = generate(user())
    origin_space = generate(space(author: owner))
    target_space = generate(space(author: target_owner))

    add_membership(origin_space, owner, :owner)
    add_membership(target_space, owner, :owner)

    {:ok, event} =
      Ash.create(
        Event,
        event_attrs(relay_policy: :admins_only_spaces),
        action: :create,
        scope: scope(owner, origin_space)
      )

    {:ok, publication} =
      Wik.Events.EventPublication
      |> Ash.Query.filter(event_id == ^event.id and target_space_id == ^origin_space.id)
      |> Ash.read_first(authorize?: false, scope: scope(owner, origin_space))

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{origin_space.slug}/events?#{%{event: publication.event_id}}")

    assert has_element?(view, testid("event-detail-relay-#{publication.id}"))

    {:ok, internal_event} =
      Ash.create(
        Event,
        event_attrs(
          relay_policy: :internal_only,
          starts_on: "2026-05-11",
          ends_on: "2026-05-11",
          title: "Internal event"
        ),
        action: :create,
        scope: scope(owner, origin_space)
      )

    {:ok, internal_publication} =
      Wik.Events.EventPublication
      |> Ash.Query.filter(event_id == ^internal_event.id and target_space_id == ^origin_space.id)
      |> Ash.read_first(authorize?: false, scope: scope(owner, origin_space))

    {:ok, internal_view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{origin_space.slug}/events?#{%{event: internal_publication.event_id}}")

    refute has_element?(internal_view, testid("event-detail-relay-#{internal_publication.id}"))
  end

  test "relay mode replaces details and successful relay returns to details", %{conn: conn} do
    owner = generate(user())
    target_owner = generate(user())
    origin_space = generate(space(author: owner))
    target_space = generate(space(author: target_owner))

    add_membership(origin_space, owner, :owner)
    add_membership(target_space, owner, :owner)

    {:ok, event} =
      Ash.create(
        Event,
        event_attrs(relay_policy: :admins_only_spaces),
        action: :create,
        scope: scope(owner, origin_space)
      )

    {:ok, publication} =
      Wik.Events.EventPublication
      |> Ash.Query.filter(event_id == ^event.id and target_space_id == ^origin_space.id)
      |> Ash.read_first(authorize?: false, scope: scope(owner, origin_space))

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{origin_space.slug}/events?#{%{event: publication.event_id}}")

    render_click(element(view, testid("event-detail-relay-#{publication.id}")))

    assert has_element?(view, testid("event-relay-form"))
    refute has_element?(view, testid("event-detail"))

    render_submit(
      form(view, testid("event-relay-form"),
        relay: %{
          "relay_note" => "Worth sharing",
          "target_space_id" => target_space.id
        }
      )
    )

    refute has_element?(view, testid("event-relay-form"))
    assert has_element?(view, testid("event-detail"))
    assert render(view) =~ "Event relayed"

    assert {:ok, relay_publication} =
             Wik.Events.EventPublication
             |> Ash.Query.filter(event_id == ^event.id and target_space_id == ^target_space.id)
             |> Ash.read_first(
               authorize?: false,
               scope: scope(owner, target_space)
             )

    assert relay_publication.relay_note == "Worth sharing"
  end

  test "relay mode can be cancelled back to details", %{conn: conn} do
    owner = generate(user())
    target_owner = generate(user())
    origin_space = generate(space(author: owner))
    target_space = generate(space(author: target_owner))

    add_membership(origin_space, owner, :owner)
    add_membership(target_space, owner, :owner)

    {:ok, event} =
      Ash.create(
        Event,
        event_attrs(relay_policy: :admins_only_spaces),
        action: :create,
        scope: scope(owner, origin_space)
      )

    {:ok, publication} =
      Wik.Events.EventPublication
      |> Ash.Query.filter(event_id == ^event.id and target_space_id == ^origin_space.id)
      |> Ash.read_first(authorize?: false, scope: scope(owner, origin_space))

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{origin_space.slug}/events?#{%{event: publication.event_id}}")

    render_click(element(view, testid("event-detail-relay-#{publication.id}")))
    assert has_element?(view, testid("event-relay-form"))

    render_click(element(view, testid("event-relay-cancel")))

    refute has_element?(view, testid("event-relay-form"))
    assert has_element?(view, testid("event-detail"))
  end

  test "events timeline groups by year, month, and day and external switch still works", %{
    conn: conn
  } do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    first_event_date = Date.utc_today() |> Date.add(10)
    second_event_date = Date.utc_today() |> Date.add(220)

    {:ok, first_event} =
      Ash.create(
        Event,
        event_attrs(
          ends_on: Date.to_iso8601(first_event_date),
          starts_on: Date.to_iso8601(first_event_date),
          title: "First gathering"
        ),
        action: :create,
        scope: scope(owner, space)
      )

    {:ok, second_event} =
      Ash.create(
        Event,
        event_attrs(
          ends_on: Date.to_iso8601(second_event_date),
          starts_on: Date.to_iso8601(second_event_date),
          title: "Second gathering"
        ),
        action: :create,
        scope: scope(owner, space)
      )

    {:ok, first_publication} =
      Wik.Events.EventPublication
      |> Ash.Query.filter(event_id == ^first_event.id and target_space_id == ^space.id)
      |> Ash.read_first(authorize?: false, scope: scope(owner, space))

    {:ok, second_publication} =
      Wik.Events.EventPublication
      |> Ash.Query.filter(event_id == ^second_event.id and target_space_id == ^space.id)
      |> Ash.read_first(authorize?: false, scope: scope(owner, space))

    {:ok, subscription} =
      Wik.Events.ExternalCalendarSubscription.create(
        %{ics_url: "https://calendar.example.test/community.ics"},
        scope: scope(owner, space)
      )

    sync_subscription!(subscription)

    external_event = first_external_event(subscription)
    external_event_date = DateTime.to_date(external_event.starts_at)
    external_event_year_testid = timeline_year_testid(external_event_date)
    external_event_month_testid = timeline_month_testid(external_event_date)
    external_event_day_testid = timeline_day_testid(external_event_date)
    external_event_testid = external_event_testid(subscription)
    first_event_year_testid = timeline_year_testid(first_event_date)
    first_event_month_testid = timeline_month_testid(first_event_date)
    first_event_day_testid = timeline_day_testid(first_event_date)
    second_event_year_testid = timeline_year_testid(second_event_date)
    second_event_month_testid = timeline_month_testid(second_event_date)
    second_event_day_testid = timeline_day_testid(second_event_date)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events?#{%{external: true}}")

    assert has_element?(view, testid(first_event_year_testid))
    assert has_element?(view, testid(first_event_month_testid))
    assert has_element?(view, testid(first_event_day_testid))
    assert has_element?(view, testid(external_event_year_testid))
    assert has_element?(view, testid(external_event_month_testid))
    assert has_element?(view, testid(external_event_day_testid))
    assert has_element?(view, testid(second_event_year_testid))
    assert has_element?(view, testid(second_event_month_testid))
    assert has_element?(view, testid(second_event_day_testid))
    assert has_element?(view, testid("event-publication-#{first_publication.id}"))
    assert has_element?(view, testid("event-publication-#{second_publication.id}"))
    assert has_element?(view, testid(external_event_testid))

    render_click(element(view, testid("events-external-toggle")))

    assert_patch(view, ~p"/#{space.slug}/events?#{%{external: false}}")
    assert has_element?(view, testid(first_event_year_testid))
    assert has_element?(view, testid(first_event_month_testid))
    assert has_element?(view, testid(first_event_day_testid))
    assert has_element?(view, testid(second_event_year_testid))
    assert has_element?(view, testid(second_event_month_testid))
    assert has_element?(view, testid(second_event_day_testid))
    assert has_element?(view, testid("event-publication-#{first_publication.id}"))
    assert has_element?(view, testid("event-publication-#{second_publication.id}"))
    refute has_element?(view, testid(external_event_month_testid))
    refute has_element?(view, testid(external_event_day_testid))
    refute has_element?(view, testid(external_event_testid))

    render_click(element(view, testid("events-external-toggle")))

    assert_patch(view, ~p"/#{space.slug}/events?#{%{external: true}}")
    assert has_element?(view, testid(external_event_month_testid))
    assert has_element?(view, testid(external_event_day_testid))
    assert has_element?(view, testid(external_event_testid))
  end

  test "all-day events group by their event-local date", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    all_day_date = Date.utc_today() |> Date.add(12)
    previous_utc_date = Date.add(all_day_date, -1)

    {:ok, event} =
      Ash.create(
        Event,
        event_attrs(
          all_day: true,
          ends_on: Date.to_iso8601(all_day_date),
          starts_on: Date.to_iso8601(all_day_date),
          title: "All-day Berlin gathering",
          tz: "Europe/Berlin"
        ),
        action: :create,
        scope: scope(owner, space)
      )

    {:ok, publication} =
      Wik.Events.EventPublication
      |> Ash.Query.filter(event_id == ^event.id and target_space_id == ^space.id)
      |> Ash.read_first(authorize?: false, scope: scope(owner, space))

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events")

    assert has_element?(view, testid(timeline_day_testid(all_day_date)))
    assert has_element?(view, testid("event-publication-#{publication.id}"))
    refute has_element?(view, testid(timeline_day_testid(previous_utc_date)))
  end

  test "converted external-backed events use the source external schedule", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, subscription} =
      Wik.Events.ExternalCalendarSubscription.create(
        %{ics_url: "https://calendar.example.test/community.ics"},
        scope: scope(owner, space)
      )

    sync_subscription!(subscription)
    external_event = first_external_event(subscription)

    assert {:ok, %{publication: publication}} =
             Events.record_external_interest(
               external_event,
               %{interest: 8, extra_info: "joining"},
               scope: scope(owner, space)
             )

    source_date = DateTime.to_date(external_event.starts_at)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events")

    assert has_element?(view, testid(timeline_day_testid(source_date)))
    assert has_element?(view, testid("event-publication-#{publication.id}"))
  end

  test "grouped timeline hides past internal events but keeps today's finished events", %{
    conn: conn
  } do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    yesterday = Date.utc_today() |> Date.add(-1)
    today = Date.utc_today()

    {:ok, past_event} =
      Ash.create(
        Event,
        event_attrs(
          ends_on: Date.to_iso8601(yesterday),
          starts_on: Date.to_iso8601(yesterday),
          title: "Past gathering",
          tz: "Etc/UTC"
        ),
        action: :create,
        scope: scope(owner, space)
      )

    {:ok, today_event} =
      Ash.create(
        Event,
        event_attrs(
          ends_at_time: "00:01",
          ends_on: Date.to_iso8601(today),
          starts_at_time: "00:00",
          starts_on: Date.to_iso8601(today),
          title: "Early gathering",
          tz: "Etc/UTC"
        ),
        action: :create,
        scope: scope(owner, space)
      )

    {:ok, past_publication} =
      Wik.Events.EventPublication
      |> Ash.Query.filter(event_id == ^past_event.id and target_space_id == ^space.id)
      |> Ash.read_first(authorize?: false, scope: scope(owner, space))

    {:ok, today_publication} =
      Wik.Events.EventPublication
      |> Ash.Query.filter(event_id == ^today_event.id and target_space_id == ^space.id)
      |> Ash.read_first(authorize?: false, scope: scope(owner, space))

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events")

    assert has_element?(view, testid(timeline_day_testid(today)))
    assert has_element?(view, testid("event-publication-#{today_publication.id}"))
    refute has_element?(view, testid("event-publication-#{past_publication.id}"))
  end

  test "grouped timeline keeps multi-day events that end today or later", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    yesterday = Date.utc_today() |> Date.add(-1)
    tomorrow = Date.utc_today() |> Date.add(1)

    {:ok, event} =
      Ash.create(
        Event,
        event_attrs(
          ends_on: Date.to_iso8601(tomorrow),
          starts_on: Date.to_iso8601(yesterday),
          title: "Multi-day gathering",
          tz: "Etc/UTC"
        ),
        action: :create,
        scope: scope(owner, space)
      )

    {:ok, publication} =
      Wik.Events.EventPublication
      |> Ash.Query.filter(event_id == ^event.id and target_space_id == ^space.id)
      |> Ash.read_first(authorize?: false, scope: scope(owner, space))

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events")

    assert has_element?(view, testid("event-publication-#{publication.id}"))
  end

  test "switching to internal removes all external rows for the swing feed", %{conn: conn} do
    previous_external_calendar = Application.get_env(:wik, Wik.Events.ExternalCalendar, [])

    Application.put_env(:wik, Wik.Events.ExternalCalendar,
      http_get: fn _url, _opts ->
        {:ok, %Req.Response{status: 200, body: File.read!("notes/basic-swing.ics")}}
      end
    )

    on_exit(fn ->
      Application.put_env(:wik, Wik.Events.ExternalCalendar, previous_external_calendar)
    end)

    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, _event} =
      Ash.create(
        Event,
        event_attrs(title: "Internal anchor"),
        action: :create,
        scope: scope(owner, space)
      )

    {:ok, subscription} =
      Wik.Events.ExternalCalendarSubscription.create(
        %{ics_url: "https://calendar.example.test/basic-swing.ics"},
        scope: scope(owner, space)
      )

    sync_subscription!(subscription)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events?#{%{external: true}}")

    assert has_element?(view, ~s([data-testid^="external-event-"]))

    render_click(element(view, testid("events-external-toggle")))

    assert_patch(view, ~p"/#{space.slug}/events?#{%{external: false}}")
    refute has_element?(view, ~s([data-testid^="external-event-"]))
  end

  test "owner can create an event from the modal", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    membership = add_membership(space, owner, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events")

    render_click(element(view, testid("events-create-button")))

    assert has_element?(view, testid("event-form"))
    assert has_element?(view, "#interest_interest")
    assert has_element?(view, "#event-interest-extra-info")
    assert has_element?(view, testid("event-tz-picker"))
    assert has_element?(view, testid("event-location-picker"))
    refute render(view) =~ ~s(name="form[location_text]")
    render_click(element(view, testid("event-form-end-date-add")))

    render_submit(
      form(view, testid("event-form"),
        form: %{
          "title" => "Community dinner",
          "description" => "Bring food to share",
          "location" => "Community Hall",
          "all_day" => "false",
          "starts_on" => "2026-05-12",
          "starts_at_time" => "18:00",
          "ends_on" => "2026-05-12",
          "ends_at_time" => "20:00",
          "relay_policy" => "admins_only_spaces",
          "tz" => "Etc/UTC"
        },
        interest: %{
          "extra_info" => "Joining around 19:00",
          "interest" => "7"
        }
      )
    )

    assert_patch(view, ~p"/#{space.slug}/events?#{%{external: false}}")
    assert has_element?(view, testid("events-timeline"))
    refute has_element?(view, testid("event-form"))
    refute has_element?(view, testid("event-detail"))

    assert %Event{} =
             event =
             Wik.Events.Event
             |> Ash.Query.filter(title == "Community dinner")
             |> Ash.read_one!(authorize?: false, scope: scope(owner, space))

    publication =
      EventPublication
      |> Ash.Query.filter(event_id == ^event.id and target_space_id == ^space.id)
      |> Ash.read_one!(authorize?: false, scope: scope(owner, space))

    assert %EventParticipation{interest: 7, extra_info: "Joining around 19:00"} =
             EventParticipation
             |> Ash.Query.filter(
               publication_id == ^publication.id and membership_id == ^membership.id
             )
             |> Ash.read_one!(authorize?: false, scope: scope(owner, space))
  end

  test "create submit shows field errors without a flash", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events")

    render_click(element(view, testid("events-create-button")))
    render_click(element(view, testid("event-form-end-date-add")))

    render_submit(
      form(view, testid("event-form"),
        form: %{
          "title" => "Community dinner",
          "description" => "Bring food to share",
          "location" => "",
          "all_day" => "false",
          "starts_on" => "2026-05-12",
          "starts_at_time" => "18:00",
          "ends_on" => "2026-05-12",
          "ends_at_time" => "20:00",
          "relay_policy" => "admins_only_spaces",
          "tz" => "Etc/UTC"
        }
      )
    )

    assert has_element?(
             view,
             ~s(#{testid("event-location-picker")} [data-role="trigger"].input-error)
           )

    refute render(view) =~ "Could not save the event"
  end

  test "typing in title does not immediately render unrelated required errors", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events")

    render_click(element(view, testid("events-create-button")))
    starts_on = input_value!(view, "event-starts-on")
    starts_at_time = input_value!(view, "event-starts-at-time")
    ends_at_time = input_value!(view, "event-ends-at-time")

    render_change(
      element(view, testid("event-form")),
      %{
        "form" => %{
          "title" => "C",
          "description" => "",
          "_unused_description" => "",
          "location" => "",
          "_unused_location" => "",
          "_unused_all_day" => "",
          "starts_on" => starts_on,
          "_unused_starts_on" => "",
          "starts_at_time" => starts_at_time,
          "_unused_starts_at_time" => "",
          "ends_at_time" => ends_at_time,
          "_unused_ends_on" => "",
          "_unused_ends_at_time" => "",
          "_unused_relay_policy" => "",
          "tz" => "Etc/UTC",
          "_unused_tz" => ""
        },
        "interest" => %{
          "extra_info" => "",
          "interest" => "5"
        }
      }
    )

    refute has_element?(view, "#event-title.input-error")

    refute has_element?(
             view,
             ~s(#{testid("event-location-picker")} [data-role="trigger"].input-error)
           )

    refute has_element?(view, ~s(#{testid("event-tz-picker")} [data-role="trigger"].input-error))
    refute has_element?(view, "#event-starts-at-time.input-error")
    refute has_element?(view, "#event-ends-at-time.input-error")
  end

  test "submitting a timed event without times shows errors under time inputs", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events")

    render_click(element(view, testid("events-create-button")))
    render_click(element(view, testid("event-form-end-date-add")))

    render_submit(
      form(view, testid("event-form"),
        form: %{
          "title" => "Community dinner",
          "description" => "",
          "location" => "Community Hall",
          "all_day" => "false",
          "starts_on" => "2026-05-12",
          "starts_at_time" => "",
          "ends_on" => "2026-05-12",
          "ends_at_time" => "",
          "relay_policy" => "internal_only",
          "tz" => "Etc/UTC"
        }
      )
    )

    html = render(view)

    assert has_element?(view, "#event-starts-at-time.input-error")
    assert has_element?(view, "#event-ends-at-time.input-error")
    refute has_element?(view, "#event-ends-on.input-error")
    assert html =~ "must be present"
  end

  test "owner can change status only in edit mode inside the detail modal", %{
    conn: conn
  } do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    event_date = future_date_string(30)

    {:ok, event} =
      Ash.create(
        Event,
        event_attrs(title: "Community dinner", relay_policy: :admins_only_spaces),
        action: :create,
        scope: scope(owner, space)
      )

    {:ok, publication} =
      Wik.Events.EventPublication
      |> Ash.Query.filter(event_id == ^event.id and target_space_id == ^space.id)
      |> Ash.read_first(authorize?: false, scope: scope(owner, space))

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events")

    assert has_element?(view, testid("event-publication-#{publication.id}"))
    refute render(view) =~ ~s(name="form[status]")

    render_click(element(view, testid("event-open-#{publication.id}")))

    assert_patch(
      view,
      ~p"/#{space.slug}/events?#{%{event: publication.event_id, external: false}}"
    )

    assert has_element?(view, testid("event-detail"))

    render_click(element(view, testid("event-detail-edit-#{publication.id}")))
    render_click(element(view, testid("event-form-end-date-add")))
    assert has_element?(view, testid("event-form"))
    assert render(view) =~ ~s(name="form[status]")

    render_submit(
      form(view, testid("event-form"),
        form: %{
          "title" => "Community dinner updated",
          "description" => "Bring extra plates",
          "location" => "Community Hall, 123 Example Street",
          "all_day" => "false",
          "starts_on" => event_date,
          "starts_at_time" => "18:30",
          "ends_on" => event_date,
          "ends_at_time" => "20:30",
          "relay_policy" => "admins_only_spaces",
          "status" => "cancelled",
          "tz" => "Etc/UTC"
        }
      )
    )

    assert_patch(view, ~p"/#{space.slug}/events?#{%{external: false}}")
    refute has_element?(view, testid("event-form"))
    refute has_element?(view, testid("event-detail"))
    assert render(view) =~ "Community dinner updated"
    assert render(view) =~ "cancelled"
  end

  test "edit submit shows field errors without a flash", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, event} =
      Ash.create(
        Event,
        event_attrs(title: "Community dinner", relay_policy: :admins_only_spaces),
        action: :create,
        scope: scope(owner, space)
      )

    {:ok, publication} =
      Wik.Events.EventPublication
      |> Ash.Query.filter(event_id == ^event.id and target_space_id == ^space.id)
      |> Ash.read_first(authorize?: false, scope: scope(owner, space))

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events")

    render_click(element(view, testid("event-open-#{publication.id}")))
    render_click(element(view, testid("event-detail-edit-#{publication.id}")))
    render_click(element(view, testid("event-form-end-date-add")))

    render_submit(
      form(view, testid("event-form"),
        form: %{
          "title" => "Community dinner updated",
          "description" => "Bring extra plates",
          "location" => "",
          "all_day" => "false",
          "starts_on" => "2026-05-12",
          "starts_at_time" => "18:30",
          "ends_on" => "2026-05-12",
          "ends_at_time" => "20:30",
          "relay_policy" => "admins_only_spaces",
          "status" => "published",
          "tz" => "Etc/UTC"
        }
      )
    )

    assert has_element?(
             view,
             ~s(#{testid("event-location-picker")} [data-role="trigger"].input-error)
           )

    refute render(view) =~ "Could not save the event"
  end

  test "edit form preloads timed event schedule values", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    starts_on = future_date_string(30)
    ends_on = future_date_string(31)

    {:ok, event} =
      Ash.create(
        Event,
        event_attrs(
          starts_on: starts_on,
          starts_at_time: "18:30",
          ends_on: ends_on,
          ends_at_time: "20:45"
        ),
        action: :create,
        scope: scope(owner, space)
      )

    {:ok, publication} =
      Wik.Events.EventPublication
      |> Ash.Query.filter(event_id == ^event.id and target_space_id == ^space.id)
      |> Ash.read_first(authorize?: false, scope: scope(owner, space))

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events")

    render_click(element(view, testid("event-open-#{publication.id}")))
    render_click(element(view, testid("event-detail-edit-#{publication.id}")))

    assert has_element?(view, "#event-starts-on[value='#{starts_on}']")
    assert has_element?(view, "#event-ends-on[value='#{ends_on}']")

    html = render(view)
    assert html =~ ~r/id="event-starts-at-time"[^>]*value="18:30(?::00)?"/
    assert html =~ ~r/id="event-ends-at-time"[^>]*value="20:45(?::00)?"/
  end

  test "create form hides end date by default and lets the user add it", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events")

    render_click(element(view, testid("events-create-button")))

    assert has_element?(view, testid("event-form-end-date-add"))
    refute has_element?(view, "#event-ends-on")

    render_click(element(view, testid("event-form-end-date-add")))

    assert has_element?(view, "#event-ends-on")
    assert has_element?(view, testid("event-form-end-date-remove"))
  end

  test "removing end date collapses it and resets it to the start date", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events")

    render_click(element(view, testid("events-create-button")))
    render_click(element(view, testid("event-form-end-date-add")))

    render_change(
      form(view, testid("event-form"),
        form: %{
          "title" => "",
          "description" => "",
          "location" => "",
          "all_day" => "false",
          "starts_on" => "2026-05-13",
          "starts_at_time" => "14:00",
          "ends_on" => "2026-05-14",
          "ends_at_time" => "16:00",
          "relay_policy" => "internal_only",
          "tz" => "Etc/UTC"
        }
      )
    )

    render_click(element(view, testid("event-form-end-date-remove")))

    refute has_element?(view, "#event-ends-on")

    render_click(element(view, testid("event-form-end-date-add")))

    assert has_element?(view, "#event-ends-on[value='2026-05-13']")
  end

  test "edit form preloads all-day event schedule values", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    starts_on = future_date_string(30)
    ends_on = future_date_string(31)

    {:ok, event} =
      Ash.create(
        Event,
        event_attrs(
          all_day: true,
          starts_on: starts_on,
          ends_on: ends_on
        ),
        action: :create,
        scope: scope(owner, space)
      )

    {:ok, publication} =
      Wik.Events.EventPublication
      |> Ash.Query.filter(event_id == ^event.id and target_space_id == ^space.id)
      |> Ash.read_first(authorize?: false, scope: scope(owner, space))

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events")

    render_click(element(view, testid("event-open-#{publication.id}")))
    render_click(element(view, testid("event-detail-edit-#{publication.id}")))

    assert has_element?(view, "#event-starts-on[value='#{starts_on}']")
    assert has_element?(view, "#event-ends-on[value='#{ends_on}']")
    refute has_element?(view, "#event-starts-at-time")
    refute has_element?(view, "#event-ends-at-time")
  end

  test "all-day toggle keeps timed values stable and relay context respects origin membership", %{
    conn: conn
  } do
    owner = generate(user())
    relay_owner = generate(user())
    origin_space = generate(space(author: owner))
    target_space = generate(space(author: relay_owner))

    add_membership(origin_space, owner, :owner)
    add_membership(origin_space, relay_owner, :admin)
    add_membership(target_space, relay_owner, :owner)
    grant_active_telegram_access(origin_space, relay_owner)

    {:ok, event} =
      Ash.create(
        Event,
        event_attrs(
          title: "Quiet walk",
          relay_policy: :admins_only_spaces
        ),
        action: :create,
        scope: scope(owner, origin_space)
      )

    {:ok, _publication} =
      Events.relay_to_space(event, target_space,
        action: :create,
        scope: scope(relay_owner, origin_space),
        relay_note: "Good fit for your space"
      )

    {:ok, view, _html} =
      conn
      |> log_in(relay_owner)
      |> live(~p"/#{target_space.slug}/events")

    refute render(view) =~ "Good fit for your space"
    refute render(view) =~ origin_space.name

    render_click(element(view, testid("events-create-button")))
    render_click(element(view, testid("event-form-end-date-add")))

    render_change(
      form(view, testid("event-form"),
        form: %{
          "title" => "",
          "description" => "",
          "location" => "",
          "all_day" => "true",
          "starts_on" => "2026-05-13",
          "ends_on" => "2026-05-14",
          "relay_policy" => "internal_only",
          "tz" => "Etc/UTC"
        }
      )
    )

    render_change(
      form(view, testid("event-form"),
        form: %{
          "title" => "",
          "description" => "",
          "location" => "",
          "all_day" => "false",
          "starts_on" => "2026-05-13",
          "ends_on" => "2026-05-14",
          "relay_policy" => "internal_only",
          "tz" => "Etc/UTC"
        }
      )
    )

    render_change(
      form(view, testid("event-form"),
        form: %{
          "title" => "",
          "description" => "",
          "location" => "",
          "all_day" => "false",
          "starts_on" => "2026-05-13",
          "starts_at_time" => "14:00",
          "ends_on" => "2026-05-14",
          "ends_at_time" => "16:00",
          "relay_policy" => "internal_only",
          "tz" => "Etc/UTC"
        }
      )
    )

    html = render(view)
    assert html =~ ~s(id="event-starts-on")
    assert html =~ ~s(id="event-ends-on")
    assert html =~ ~s(id="event-starts-at-time")
    assert html =~ ~s(id="event-ends-at-time")
    assert html =~ ~s(type="time")
  end

  test "validate keeps all-day and timed date inputs stable while editing other fields", %{
    conn: conn
  } do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events")

    render_click(element(view, testid("events-create-button")))
    render_click(element(view, testid("event-form-end-date-add")))

    render_change(
      form(view, testid("event-form"),
        form: %{
          "title" => "",
          "description" => "",
          "location" => "",
          "all_day" => "true",
          "starts_on" => "2026-05-13",
          "ends_on" => "2026-05-14",
          "relay_policy" => "internal_only",
          "tz" => "Etc/UTC"
        }
      )
    )

    render_change(
      form(view, testid("event-form"),
        form: %{
          "title" => "Quiet walk",
          "description" => "",
          "location" => "",
          "all_day" => "true",
          "starts_on" => "2026-05-13",
          "ends_on" => "2026-05-14",
          "relay_policy" => "internal_only",
          "tz" => "Etc/UTC"
        }
      )
    )

    assert has_element?(view, "#event-starts-on[value='2026-05-13']")
    assert has_element?(view, "#event-ends-on[value='2026-05-14']")

    render_change(
      form(view, testid("event-form"),
        form: %{
          "title" => "Quiet walk",
          "description" => "",
          "location" => "",
          "all_day" => "false",
          "starts_on" => "2026-05-13",
          "ends_on" => "2026-05-14",
          "relay_policy" => "internal_only",
          "tz" => "Etc/UTC"
        }
      )
    )

    render_change(
      form(view, testid("event-form"),
        form: %{
          "title" => "Quiet walk",
          "description" => "",
          "location" => "",
          "all_day" => "false",
          "starts_on" => "2026-05-13",
          "starts_at_time" => "14:00",
          "ends_on" => "2026-05-14",
          "ends_at_time" => "16:00",
          "relay_policy" => "internal_only",
          "tz" => "Etc/UTC"
        }
      )
    )

    render_change(
      form(view, testid("event-form"),
        form: %{
          "title" => "Quiet walk updated",
          "description" => "",
          "location" => "",
          "all_day" => "false",
          "starts_on" => "2026-05-13",
          "starts_at_time" => "14:00",
          "ends_on" => "2026-05-14",
          "ends_at_time" => "16:00",
          "relay_policy" => "internal_only",
          "tz" => "Etc/UTC"
        }
      )
    )

    assert has_element?(view, "#event-starts-on[value='2026-05-13']")
    assert has_element?(view, "#event-ends-on[value='2026-05-14']")

    html = render(view)
    assert html =~ ~s(id="event-starts-at-time")
    assert html =~ ~s(id="event-ends-at-time")
    assert html =~ ~r/id="event-starts-at-time"[^>]*value="14:00(?::00)?"/
    assert html =~ ~r/id="event-ends-at-time"[^>]*value="16:00(?::00)?"/
  end

  test "renders both event tz and user tz when they differ", %{conn: conn} do
    owner = generate(user())
    member = generate(user())
    space = generate(space(author: owner))

    add_membership(space, owner, :owner)
    add_membership(space, member, :member)
    grant_active_telegram_access(space, member)

    {:ok, _event} =
      Ash.create(
        Event,
        event_attrs(
          title: "Berlin dinner",
          starts_on: future_date_string(30),
          starts_at_time: "18:00",
          ends_on: future_date_string(30),
          ends_at_time: "20:00",
          tz: "Europe/Berlin"
        ),
        action: :create,
        scope: scope(owner, space)
      )

    {:ok, view, _html} =
      conn
      |> log_in(member)
      |> live(~p"/#{space.slug}/events")

    html = render(view)
    assert html =~ "Europe/Berlin"
    assert html =~ "Etc/UTC"
  end

  test "does not render both timezones when wall-clock times are equivalent", %{conn: conn} do
    owner = generate(user())
    member = generate(user(tz: "Europe/Amsterdam"))
    space = generate(space(author: owner))

    add_membership(space, owner, :owner)
    add_membership(space, member, :member)
    grant_active_telegram_access(space, member)

    {:ok, _event} =
      Ash.create(
        Event,
        event_attrs(
          title: "European dinner",
          starts_on: future_date_string(30),
          starts_at_time: "18:00",
          ends_on: future_date_string(30),
          ends_at_time: "20:00",
          tz: "Europe/Berlin"
        ),
        action: :create,
        scope: scope(owner, space)
      )

    {:ok, view, _html} =
      conn
      |> log_in(member)
      |> live(~p"/#{space.slug}/events")

    html = render(view)
    refute html =~ "Europe/Berlin"
    refute html =~ "Europe/Amsterdam"
  end

  test "edit form timezone picker reflects the event timezone", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, _event} =
      Ash.create(
        Event,
        event_attrs(
          starts_on: future_date_string(30),
          ends_on: future_date_string(30),
          tz: "Europe/Berlin",
          title: "Berlin event"
        ),
        action: :create,
        scope: scope(owner, space)
      )

    [publication] =
      Ash.read!(
        Wik.Events.EventPublication,
        authorize?: false,
        scope: scope(owner, space)
      )

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events?#{%{event: publication.event_id}}")

    render_click(element(view, testid("event-detail-edit-#{publication.id}")))

    assert has_element?(view, testid("event-form"))

    assert has_element?(
             view,
             ~s(#{testid("event-tz-picker")} input[data-role="value"][value="Europe/Berlin"])
           )
  end

  test "owner can subscribe to an external calendar and sees imported events on revisit", %{
    conn: conn
  } do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events?#{%{external: true}}")

    assert has_element?(view, testid("events-subscribe-to-calendar-button"))
    assert has_element?(view, testid("events-subscriptions-empty"))

    render_click(element(view, testid("events-subscribe-to-calendar-button")))
    assert has_element?(view, testid("events-subscription-form"))

    render_submit(
      form(view, testid("events-subscription-form"),
        subscription: %{"ics_url" => "https://calendar.example.test/community.ics"}
      )
    )

    [subscription] =
      Ash.read!(
        Wik.Events.ExternalCalendarSubscription,
        authorize?: false,
        scope: scope(owner, space)
      )

    assert has_element?(view, testid("events-subscription-open-#{subscription.id}"))
    render_click(element(view, testid("events-subscription-open-#{subscription.id}")))
    assert has_element?(view, testid("events-subscription-name-form"))
    assert render(view) =~ "Community Coordination Calendar"
    assert render(view) =~ "https://calendar.example.test/community.ics"

    render_submit(
      form(view, testid("events-subscription-name-form"),
        subscription_name: %{"custom_name" => "Short name"}
      )
    )

    refute has_element?(view, testid("events-subscription-name-form"))
    assert render(view) =~ "Short name"

    external_event_testid = external_event_testid(subscription)
    assert has_element?(view, testid(external_event_testid))

    assert has_element?(
             view,
             testid(external_event_calendar_name_testid(subscription)),
             "Short name"
           )

    {:ok, revisited_view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events?#{%{external: true}}")

    assert has_element?(revisited_view, testid("events-subscription-open-#{subscription.id}"))

    assert has_element?(
             revisited_view,
             testid("events-subscription-open-#{subscription.id}"),
             "Short name"
           )

    assert has_element?(revisited_view, testid(external_event_testid))

    assert has_element?(
             revisited_view,
             testid(external_event_calendar_name_testid(subscription)),
             "Short name"
           )
  end

  test "subscription submit trims surrounding whitespace from the ics url", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events?#{%{external: true}}")

    render_click(element(view, testid("events-subscribe-to-calendar-button")))

    render_submit(
      form(view, testid("events-subscription-form"),
        subscription: %{
          "ics_url" => "  https://calendar.example.test/community.ics \n"
        }
      )
    )

    [subscription] =
      Ash.read!(
        Wik.Events.ExternalCalendarSubscription,
        authorize?: false,
        scope: scope(owner, space)
      )

    assert subscription.ics_url == "https://calendar.example.test/community.ics"
  end

  test "external event rows fall back to the subscription url when the feed has no calendar name",
       %{
         conn: conn
       } do
    previous_external_calendar = Application.get_env(:wik, Wik.Events.ExternalCalendar, [])

    Application.put_env(:wik, Wik.Events.ExternalCalendar,
      http_get: fn _url, _opts ->
        {:ok, %Req.Response{status: 200, body: sample_ics_calendar_without_name()}}
      end
    )

    on_exit(fn ->
      Application.put_env(:wik, Wik.Events.ExternalCalendar, previous_external_calendar)
    end)

    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, subscription} =
      Wik.Events.ExternalCalendarSubscription.create(
        %{ics_url: "https://calendar.example.test/unnamed.ics"},
        scope: scope(owner, space)
      )

    sync_subscription!(subscription)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events?#{%{external: true}}")

    assert has_element?(
             view,
             testid(external_event_calendar_name_testid(subscription)),
             "https://calendar.example.test/unnamed.ics"
           )
  end

  test "external events open in the shared event modal", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, subscription} =
      Wik.Events.ExternalCalendarSubscription.create(
        %{ics_url: "https://calendar.example.test/community.ics"},
        scope: scope(owner, space)
      )

    sync_subscription!(subscription)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events?#{%{external: true}}")

    external_event_id = external_event_id(subscription)

    render_click(element(view, testid("event-open-#{external_event_id}")))

    assert has_element?(view, testid("external-event-detail"))
    assert render(view) =~ "External dinner"
    assert render(view) =~ "Imported from an external calendar"
    assert render(view) =~ "Community Coordination Calendar"
  end

  test "external events keep UTC presentation timezone for UTC ICS timestamps", %{conn: _conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, subscription} =
      Wik.Events.ExternalCalendarSubscription.create(
        %{ics_url: "https://calendar.example.test/community.ics"},
        scope: scope(owner, space)
      )

    sync_subscription!(subscription)

    external_event =
      Events.ExternalEvent
      |> Ash.Query.filter(subscription_id == ^subscription.id)
      |> Ash.read_first!(authorize?: false, scope: scope(owner, space))

    assert external_event.tz == "Etc/UTC"
  end

  test "subscription modal shows original calendar metadata from the feed", %{conn: conn} do
    previous_external_calendar = Application.get_env(:wik, Wik.Events.ExternalCalendar, [])

    Application.put_env(:wik, Wik.Events.ExternalCalendar,
      http_get: fn _url, _opts ->
        {:ok, %Req.Response{status: 200, body: sample_ics_calendar_with_metadata()}}
      end
    )

    on_exit(fn ->
      Application.put_env(:wik, Wik.Events.ExternalCalendar, previous_external_calendar)
    end)

    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, subscription} =
      Wik.Events.ExternalCalendarSubscription.create(
        %{ics_url: "https://calendar.example.test/community.ics"},
        scope: scope(owner, space)
      )

    sync_subscription!(subscription)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events?#{%{external: true}}")

    render_click(element(view, testid("events-subscription-open-#{subscription.id}")))

    assert has_element?(view, testid("events-subscription-name-form"))
    assert render(view) =~ "Community Coordination Calendar"
    assert render(view) =~ "Europe/Berlin"
    assert render(view) =~ "Community events for coordination"
    assert render(view) =~ "Bring friends"
  end

  test "expired bounded recurring external events are not materialized", %{conn: conn} do
    previous_external_calendar = Application.get_env(:wik, Wik.Events.ExternalCalendar, [])

    Application.put_env(:wik, Wik.Events.ExternalCalendar,
      http_get: fn _url, _opts ->
        {:ok, %Req.Response{status: 200, body: sample_ics_expired_recurring_calendar()}}
      end
    )

    on_exit(fn ->
      Application.put_env(:wik, Wik.Events.ExternalCalendar, previous_external_calendar)
    end)

    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, subscription} =
      Wik.Events.ExternalCalendarSubscription.create(
        %{ics_url: "https://calendar.example.test/expired-recurring.ics"},
        scope: scope(owner, space)
      )

    sync_subscription!(subscription)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events?#{%{external: true}}")

    assert external_event_id(subscription) == nil
    refute has_element?(view, ~s([data-testid^="external-event-"]))
  end

  test "expired recurring external events with raw UNTIL are not materialized", %{conn: conn} do
    previous_external_calendar = Application.get_env(:wik, Wik.Events.ExternalCalendar, [])

    Application.put_env(:wik, Wik.Events.ExternalCalendar,
      http_get: fn _url, _opts ->
        {:ok, %Req.Response{status: 200, body: sample_ics_expired_until_recurring_calendar()}}
      end
    )

    on_exit(fn ->
      Application.put_env(:wik, Wik.Events.ExternalCalendar, previous_external_calendar)
    end)

    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, subscription} =
      Wik.Events.ExternalCalendarSubscription.create(
        %{ics_url: "https://calendar.example.test/expired-until-recurring.ics"},
        scope: scope(owner, space)
      )

    sync_subscription!(subscription)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events?#{%{external: true}}")

    assert external_event_id(subscription) == nil
    refute has_element?(view, ~s([data-testid^="external-event-"]))
  end

  test "recurring external events keep their real local wall-clock start time", %{conn: _conn} do
    previous_external_calendar = Application.get_env(:wik, Wik.Events.ExternalCalendar, [])

    Application.put_env(:wik, Wik.Events.ExternalCalendar,
      http_get: fn _url, _opts ->
        {:ok, %Req.Response{status: 200, body: sample_ics_future_recurring_calendar()}}
      end
    )

    on_exit(fn ->
      Application.put_env(:wik, Wik.Events.ExternalCalendar, previous_external_calendar)
    end)

    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, subscription} =
      Wik.Events.ExternalCalendarSubscription.create(
        %{ics_url: "https://calendar.example.test/future-recurring.ics"},
        scope: scope(owner, space)
      )

    sync_subscription!(subscription)

    external_event =
      Events.ExternalEvent
      |> Ash.Query.filter(subscription_id == ^subscription.id)
      |> Ash.Query.sort(starts_at: :asc)
      |> Ash.read_first!(authorize?: false, scope: scope(owner, space))

    assert external_event.tz == "Europe/Berlin"

    expected_starts_at =
      sample_ics_future_date()
      |> DateTime.new!(~T[20:45:00], "Europe/Berlin")
      |> DateTime.shift_zone!("Etc/UTC")

    expected_ends_at =
      sample_ics_future_date()
      |> DateTime.new!(~T[22:00:00], "Europe/Berlin")
      |> DateTime.shift_zone!("Etc/UTC")

    assert DateTime.compare(external_event.starts_at, expected_starts_at) == :eq
    assert DateTime.compare(external_event.ends_at, expected_ends_at) == :eq
  end

  test "external event modal sanitizes html descriptions and keeps safe links", %{conn: conn} do
    previous_external_calendar = Application.get_env(:wik, Wik.Events.ExternalCalendar, [])

    Application.put_env(:wik, Wik.Events.ExternalCalendar,
      http_get: fn _url, _opts ->
        {:ok, %Req.Response{status: 200, body: sample_ics_calendar_with_html_description()}}
      end
    )

    on_exit(fn ->
      Application.put_env(:wik, Wik.Events.ExternalCalendar, previous_external_calendar)
    end)

    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, subscription} =
      Wik.Events.ExternalCalendarSubscription.create(
        %{ics_url: "https://calendar.example.test/community.ics"},
        scope: scope(owner, space)
      )

    sync_subscription!(subscription)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events?#{%{external: true}}")

    external_event_id = external_event_id(subscription)

    render_click(element(view, testid("event-open-#{external_event_id}")))

    assert has_element?(view, testid("external-event-detail"))
    assert has_element?(view, ~s(a[href="http://www.werk36.de"]))

    document =
      view
      |> render()
      |> LazyHTML.from_fragment()

    refute document |> LazyHTML.query("script") |> Enum.any?()
    refute document |> LazyHTML.query("img") |> Enum.any?()
  end

  test "owner can remove an external calendar subscription", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, subscription} =
      Wik.Events.ExternalCalendarSubscription.create(
        %{ics_url: "https://calendar.example.test/community.ics"},
        scope: scope(owner, space)
      )

    sync_subscription!(subscription)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events?#{%{external: true}}")

    external_event_testid = external_event_testid(subscription)

    assert has_element?(view, testid("events-subscription-open-#{subscription.id}"))
    assert has_element?(view, testid(external_event_testid))
    render_click(element(view, testid("events-subscription-open-#{subscription.id}")))
    assert has_element?(view, testid("events-subscription-name-form"))

    render_click(element(view, testid("events-subscription-remove-#{subscription.id}")))

    refute has_element?(view, testid("events-subscription-open-#{subscription.id}"))
    refute has_element?(view, testid(external_event_testid))
    refute has_element?(view, testid("events-subscription-name-form"))
  end

  test "owner can refresh an external calendar subscription from the modal", %{conn: conn} do
    previous_external_calendar = Application.get_env(:wik, Wik.Events.ExternalCalendar, [])
    counter = start_supervised!({Agent, fn -> 0 end})

    Application.put_env(:wik, Wik.Events.ExternalCalendar,
      http_get: fn _url, _opts ->
        Agent.update(counter, &(&1 + 1))
        {:ok, %Req.Response{status: 200, body: sample_ics_calendar()}}
      end
    )

    on_exit(fn ->
      Application.put_env(:wik, Wik.Events.ExternalCalendar, previous_external_calendar)
    end)

    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, subscription} =
      Wik.Events.ExternalCalendarSubscription.create(
        %{ics_url: "https://calendar.example.test/community.ics"},
        scope: scope(owner, space)
      )

    sync_subscription!(subscription)
    assert Agent.get(counter, & &1) == 1

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events?#{%{external: true}}")

    render_click(element(view, testid("events-subscription-open-#{subscription.id}")))
    assert has_element?(view, testid("events-subscription-name-form"))

    render_click(element(view, testid("events-subscription-refresh-#{subscription.id}")))

    assert Agent.get(counter, & &1) == 2
    assert has_element?(view, testid("events-subscription-name-form"))
  end

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false
    )
  end

  defp event_attrs(overrides) do
    %{
      all_day: false,
      description: "An event description",
      ends_at_time: "20:00",
      ends_on: future_date_string(30),
      location: "Community Hall, 123 Example Street",
      relay_policy: :internal_only,
      starts_at_time: "18:00",
      starts_on: future_date_string(30),
      tz: "Etc/UTC",
      title: "Shared Dinner"
    }
    |> Map.merge(Enum.into(overrides, %{}))
  end

  defp input_value!(view, id) do
    selector = "input##{id}"

    assert has_element?(view, selector), "expected input ##{id} to exist"

    case view
         |> element(selector)
         |> render()
         |> LazyHTML.from_fragment()
         |> LazyHTML.attribute("value") do
      [value] -> value
      [] -> flunk("expected input ##{id} to have a value")
    end
  end

  defp scope(actor, tenant) do
    %Wik.Scope{actor: actor, tenant: tenant}
  end

  defp log_in(conn, user) do
    {:ok, token, _claims} = Jwt.token_for_user(user)
    user = Ash.Resource.set_metadata(user, %{token: token})

    conn
    |> init_test_session(%{})
    |> AuthHelpers.store_in_session(user)
  end

  defp sync_subscription!(subscription) do
    assert {:ok, _subscription} = ExternalCalendar.sync_subscription(subscription)
  end

  defp timeline_year_testid(%Date{} = date), do: "events-year-#{date.year}"

  defp timeline_month_testid(%Date{} = date), do: "events-month-#{date.year}-#{date.month}"

  defp timeline_day_testid(%Date{} = date),
    do: "events-day-#{date.year}-#{date.month}-#{date.day}"

  defp first_external_event(subscription) do
    from(event in ExternalEvent,
      where: event.subscription_id == ^subscription.id,
      order_by: [asc: event.starts_at],
      limit: 1
    )
    |> Repo.one()
  end

  defp external_event_id(subscription) do
    external_event = first_external_event(subscription)

    external_event && "external:#{external_event.id}"
  end

  defp external_event_testid(subscription) do
    external_event_id(subscription) && "external-event-#{external_event_id(subscription)}"
  end

  defp external_event_calendar_name_testid(subscription) do
    external_event_id(subscription) &&
      "external-event-calendar-name-#{external_event_id(subscription)}"
  end

  defp sample_ics_future_date do
    date = Date.utc_today() |> Date.add(30)
    Date.add(date, rem(4 - Date.day_of_week(date) + 7, 7))
  end

  defp sample_ics_future_date_compact do
    sample_ics_future_date()
    |> Date.to_iso8601()
    |> String.replace("-", "")
  end

  defp sample_ics_calendar do
    """
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:-//Wik//Events Test//EN
    X-WR-CALNAME:Community Coordination Calendar
    BEGIN:VEVENT
    UID:past-dinner
    DTSTAMP:20250529T120000Z
    DTSTART:20250501T180000Z
    DTEND:20250501T200000Z
    SUMMARY:Past external dinner
    DESCRIPTION:This old event should stay hidden
    LOCATION:Old Riverside Hall
    STATUS:CONFIRMED
    END:VEVENT
    BEGIN:VEVENT
    UID:external-dinner
    DTSTAMP:20260529T120000Z
    DTSTART:#{sample_ics_future_date_compact()}T180000Z
    DTEND:#{sample_ics_future_date_compact()}T200000Z
    SUMMARY:External dinner
    DESCRIPTION:Imported from an external calendar
    LOCATION:Riverside Hall
    STATUS:CONFIRMED
    END:VEVENT
    END:VCALENDAR
    """
  end

  defp sample_ics_calendar_without_name do
    """
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:-//Wik//Events Test//EN
    BEGIN:VEVENT
    UID:external-dinner
    DTSTAMP:20260529T120000Z
    DTSTART:#{sample_ics_future_date_compact()}T180000Z
    DTEND:#{sample_ics_future_date_compact()}T200000Z
    SUMMARY:External dinner
    DESCRIPTION:Imported from an external calendar
    LOCATION:Riverside Hall
    STATUS:CONFIRMED
    END:VEVENT
    END:VCALENDAR
    """
  end

  defp sample_ics_calendar_with_html_description do
    """
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:-//Wik//Events Test//EN
    X-WR-CALNAME:Community Coordination Calendar
    BEGIN:VEVENT
    UID:external-dinner
    DTSTAMP:20260529T120000Z
    DTSTART:#{sample_ics_future_date_compact()}T180000Z
    DTEND:#{sample_ics_future_date_compact()}T200000Z
    SUMMARY:External dinner
    DESCRIPTION:West Coast Swing Party\\n<a href="https://www.google.com/url?q=http://www.werk36.de&amp;sa=D&amp;source=calendar&amp;usd=2&amp;usg=AOvVaw1yIVflEmW8GH3zDYw07XmQ" target="_blank">www.werk36.de</a>\\n<script>alert(1)</script><img src="https://www.example.com/x.png" onerror="alert(1)">
    LOCATION:Riverside Hall
    STATUS:CONFIRMED
    END:VEVENT
    END:VCALENDAR
    """
  end

  defp sample_ics_calendar_with_metadata do
    """
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:-//Wik//Events Test//EN
    X-WR-CALNAME:Community Coordination Calendar
    X-WR-TIMEZONE:Europe/Berlin
    X-WR-CALDESC:Community events for coordination\\nBring friends
    BEGIN:VEVENT
    UID:external-dinner
    DTSTAMP:20260529T120000Z
    DTSTART:#{sample_ics_future_date_compact()}T180000Z
    DTEND:#{sample_ics_future_date_compact()}T200000Z
    SUMMARY:External dinner
    DESCRIPTION:Imported from an external calendar
    LOCATION:Riverside Hall
    STATUS:CONFIRMED
    END:VEVENT
    END:VCALENDAR
    """
  end

  defp sample_ics_expired_recurring_calendar do
    """
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:-//Wik//Events Test//EN
    X-WR-CALNAME:Expired Recurring Calendar
    BEGIN:VEVENT
    UID:expired-series
    DTSTAMP:20260529T120000Z
    DTSTART;TZID=Europe/Berlin:20220609T204500
    DTEND;TZID=Europe/Berlin:20220609T220000
    RRULE:FREQ=WEEKLY;WKST=MO;COUNT=5;BYDAY=TH
    SUMMARY:Expired recurring external event
    DESCRIPTION:Should not be rematerialized in 2026
    LOCATION:Riverside Hall
    STATUS:CONFIRMED
    END:VEVENT
    END:VCALENDAR
    """
  end

  defp sample_ics_future_recurring_calendar do
    """
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:-//Wik//Events Test//EN
    X-WR-CALNAME:Future Recurring Calendar
    BEGIN:VEVENT
    UID:future-series
    DTSTAMP:20260529T120000Z
    DTSTART;TZID=Europe/Berlin:#{sample_ics_future_date_compact()}T204500
    DTEND;TZID=Europe/Berlin:#{sample_ics_future_date_compact()}T220000
    RRULE:FREQ=WEEKLY;WKST=MO;COUNT=2;BYDAY=TH
    SUMMARY:Future recurring external event
    DESCRIPTION:Should keep its Berlin-local wall clock time
    LOCATION:Riverside Hall
    STATUS:CONFIRMED
    END:VEVENT
    END:VCALENDAR
    """
  end

  defp sample_ics_expired_until_recurring_calendar do
    """
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:-//Wik//Events Test//EN
    X-WR-CALNAME:Expired Until Recurring Calendar
    BEGIN:VEVENT
    UID:expired-until-series
    DTSTAMP:20260529T120000Z
    DTSTART;TZID=Europe/Berlin:20220802T193500
    DTEND;TZID=Europe/Berlin:20220802T203500
    RRULE:FREQ=WEEKLY;WKST=MO;UNTIL=20221220;BYDAY=TU
    SUMMARY:Expired until recurring external event
    DESCRIPTION:Should not be rematerialized in 2026
    LOCATION:Riverside Hall
    STATUS:CONFIRMED
    END:VEVENT
    END:VCALENDAR
    """
  end

  defp set_username(membership, username) do
    Ash.update!(membership, %{username: username},
      action: :set_username,
      authorize?: false,
      domain: Wik.Accounts
    )
  end
end
