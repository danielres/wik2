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

    assert_patch(view, ~p"/#{space.slug}/events?#{%{event: publication.id, external: false}}")
    assert has_element?(view, testid("event-detail"))
    assert render(view) =~ "An event description"
    assert render(view) =~ "Community Hall, 123 Example Street"

    assert has_element?(view, testid("event-location-google-maps-link"))
    assert render(view) =~ "https://www.google.com/maps/search/"
    assert render(view) =~ "Community+Hall%2C+123+Example+Street"
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
      |> live(~p"/#{origin_space.slug}/events?#{%{event: publication.id}}")

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
      |> live(~p"/#{origin_space.slug}/events?#{%{event: internal_publication.id}}")

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
      |> live(~p"/#{origin_space.slug}/events?#{%{event: publication.id}}")

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
      |> live(~p"/#{origin_space.slug}/events?#{%{event: publication.id}}")

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

    {:ok, may_event} =
      Ash.create(
        Event,
        event_attrs(title: "May gathering"),
        action: :create,
        scope: scope(owner, space)
      )

    {:ok, january_event} =
      Ash.create(
        Event,
        event_attrs(
          ends_on: "2027-01-15",
          starts_on: "2027-01-15",
          title: "January gathering"
        ),
        action: :create,
        scope: scope(owner, space)
      )

    {:ok, may_publication} =
      Wik.Events.EventPublication
      |> Ash.Query.filter(event_id == ^may_event.id and target_space_id == ^space.id)
      |> Ash.read_first(authorize?: false, scope: scope(owner, space))

    {:ok, january_publication} =
      Wik.Events.EventPublication
      |> Ash.Query.filter(event_id == ^january_event.id and target_space_id == ^space.id)
      |> Ash.read_first(authorize?: false, scope: scope(owner, space))

    {:ok, subscription} =
      Wik.Events.ExternalCalendarSubscription.create(
        %{ics_url: "https://calendar.example.test/community.ics"},
        scope: scope(owner, space)
      )

    sync_subscription!(subscription)

    external_event_testid = external_event_testid(subscription)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events?#{%{external: true}}")

    assert has_element?(view, testid("events-year-2026"))
    assert has_element?(view, testid("events-month-2026-5"))
    assert has_element?(view, testid("events-day-2026-5-10"))
    assert has_element?(view, testid("events-month-2026-6"))
    assert has_element?(view, testid("events-day-2026-6-1"))
    assert has_element?(view, testid("events-year-2027"))
    assert has_element?(view, testid("events-month-2027-1"))
    assert has_element?(view, testid("events-day-2027-1-15"))
    assert has_element?(view, testid("event-publication-#{may_publication.id}"))
    assert has_element?(view, testid("event-publication-#{january_publication.id}"))
    assert has_element?(view, testid(external_event_testid))

    render_click(element(view, testid("events-external-toggle")))

    assert_patch(view, ~p"/#{space.slug}/events?#{%{external: false}}")
    assert has_element?(view, testid("events-year-2026"))
    assert has_element?(view, testid("events-month-2026-5"))
    assert has_element?(view, testid("events-day-2026-5-10"))
    assert has_element?(view, testid("events-year-2027"))
    assert has_element?(view, testid("events-month-2027-1"))
    assert has_element?(view, testid("events-day-2027-1-15"))
    assert has_element?(view, testid("event-publication-#{may_publication.id}"))
    assert has_element?(view, testid("event-publication-#{january_publication.id}"))
    refute has_element?(view, testid("events-month-2026-6"))
    refute has_element?(view, testid("events-day-2026-6-1"))
    refute has_element?(view, testid(external_event_testid))

    render_click(element(view, testid("events-external-toggle")))

    assert_patch(view, ~p"/#{space.slug}/events?#{%{external: true}}")
    assert has_element?(view, testid("events-month-2026-6"))
    assert has_element?(view, testid("events-day-2026-6-1"))
    assert has_element?(view, testid(external_event_testid))
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
    add_membership(space, owner, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/events")

    render_click(element(view, testid("events-create-button")))

    assert has_element?(view, testid("event-modal-dialog"))
    assert has_element?(view, testid("event-tz-picker"))
    assert has_element?(view, testid("event-location-picker"))
    refute render(view) =~ ~s(name="form[location_text]")

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
          "provenance_policy" => "visible",
          "tz" => "Etc/UTC"
        }
      )
    )

    assert_patch(view, ~p"/#{space.slug}/events?#{%{external: false}}")
    assert has_element?(view, testid("events-timeline"))
    refute has_element?(view, testid("event-form"))
    refute has_element?(view, testid("event-detail"))

    assert %Wik.Events.Event{} =
             Wik.Events.Event
             |> Ash.Query.filter(title == "Community dinner")
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
          "provenance_policy" => "visible",
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

  test "owner can change status only in edit mode inside the detail modal", %{
    conn: conn
  } do
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

    assert has_element?(view, testid("event-publication-#{publication.id}"))
    refute render(view) =~ ~s(name="form[status]")

    render_click(element(view, testid("event-open-#{publication.id}")))
    assert_patch(view, ~p"/#{space.slug}/events?#{%{event: publication.id, external: false}}")
    assert has_element?(view, testid("event-detail"))

    render_click(element(view, testid("event-detail-edit-#{publication.id}")))
    assert has_element?(view, testid("event-form"))
    assert render(view) =~ ~s(name="form[status]")

    render_submit(
      form(view, testid("event-form"),
        form: %{
          "title" => "Community dinner updated",
          "description" => "Bring extra plates",
          "location" => "Community Hall, 123 Example Street",
          "all_day" => "false",
          "starts_on" => "2026-05-12",
          "starts_at_time" => "18:30",
          "ends_on" => "2026-05-12",
          "ends_at_time" => "20:30",
          "relay_policy" => "admins_only_spaces",
          "provenance_policy" => "visible",
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
          "provenance_policy" => "visible",
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

    {:ok, event} =
      Ash.create(
        Event,
        event_attrs(
          starts_on: "2026-05-12",
          starts_at_time: "18:30",
          ends_on: "2026-05-13",
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

    assert has_element?(view, "#event-starts-on[value='2026-05-12']")
    assert has_element?(view, "#event-ends-on[value='2026-05-13']")

    html = render(view)
    assert html =~ ~r/id="event-starts-at-time"[^>]*value="18:30(?::00)?"/
    assert html =~ ~r/id="event-ends-at-time"[^>]*value="20:45(?::00)?"/
  end

  test "edit form preloads all-day event schedule values", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, event} =
      Ash.create(
        Event,
        event_attrs(
          all_day: true,
          starts_on: "2026-05-12",
          ends_on: "2026-05-13"
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

    assert has_element?(view, "#event-starts-on[value='2026-05-12']")
    assert has_element?(view, "#event-ends-on[value='2026-05-13']")
    refute has_element?(view, "#event-starts-at-time")
    refute has_element?(view, "#event-ends-at-time")
  end

  test "all-day toggle keeps timed values and provenance hidden suppresses relay context", %{
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
          provenance_policy: :hidden,
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
          "provenance_policy" => "visible",
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
          "provenance_policy" => "visible",
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
          "provenance_policy" => "visible",
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
          "provenance_policy" => "visible",
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
          "provenance_policy" => "visible",
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
          "provenance_policy" => "visible",
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
          "provenance_policy" => "visible",
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
          "provenance_policy" => "visible",
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
          starts_on: "2026-05-12",
          starts_at_time: "18:00",
          ends_on: "2026-05-12",
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

  test "edit form timezone picker reflects the event timezone", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, _event} =
      Ash.create(
        Event,
        event_attrs(
          starts_on: "2026-05-16",
          ends_on: "2026-05-16",
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
      |> live(~p"/#{space.slug}/events?#{%{event: publication.id}}")

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
    assert has_element?(view, testid("events-subscription-detail-dialog"))
    assert render(view) =~ "Community Coordination Calendar"
    assert render(view) =~ "https://calendar.example.test/community.ics"

    render_submit(
      form(view, testid("events-subscription-name-form"),
        subscription_name: %{"custom_name" => "Short name"}
      )
    )

    refute has_element?(view, testid("events-subscription-detail-dialog"))
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

    assert has_element?(view, testid("event-modal-dialog"))
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

    assert has_element?(view, testid("events-subscription-detail-dialog"))
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
    assert external_event.starts_at == ~U[2026-06-04 18:45:00.000000Z]
    assert external_event.ends_at == ~U[2026-06-04 20:00:00.000000Z]
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
    assert has_element?(view, testid("events-subscription-detail-dialog"))

    render_click(element(view, testid("events-subscription-remove-#{subscription.id}")))

    refute has_element?(view, testid("events-subscription-open-#{subscription.id}"))
    refute has_element?(view, testid(external_event_testid))
    refute has_element?(view, testid("events-subscription-detail-dialog"))
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
    assert has_element?(view, testid("events-subscription-detail-dialog"))

    render_click(element(view, testid("events-subscription-refresh-#{subscription.id}")))

    assert Agent.get(counter, & &1) == 2
    assert has_element?(view, testid("events-subscription-detail-dialog"))
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
      ends_on: "2026-05-10",
      location: "Community Hall, 123 Example Street",
      provenance_policy: :visible,
      relay_policy: :internal_only,
      starts_at_time: "18:00",
      starts_on: "2026-05-10",
      tz: "Etc/UTC",
      title: "Shared Dinner"
    }
    |> Map.merge(Enum.into(overrides, %{}))
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

  defp external_event_id(subscription) do
    external_event =
      from(event in ExternalEvent,
        where: event.subscription_id == ^subscription.id,
        order_by: [asc: event.starts_at],
        limit: 1
      )
      |> Repo.one()

    external_event && "external:#{external_event.id}"
  end

  defp external_event_testid(subscription) do
    external_event_id(subscription) && "external-event-#{external_event_id(subscription)}"
  end

  defp external_event_calendar_name_testid(subscription) do
    external_event_id(subscription) &&
      "external-event-calendar-name-#{external_event_id(subscription)}"
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
    DTSTART:20260601T180000Z
    DTEND:20260601T200000Z
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
    DTSTART:20260601T180000Z
    DTEND:20260601T200000Z
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
    DTSTART:20260601T180000Z
    DTEND:20260601T200000Z
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
    DTSTART:20260601T180000Z
    DTEND:20260601T200000Z
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
    DTSTART;TZID=Europe/Berlin:20260604T204500
    DTEND;TZID=Europe/Berlin:20260604T220000
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
end
