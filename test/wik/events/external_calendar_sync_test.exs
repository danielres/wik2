defmodule Wik.Events.ExternalCalendarSyncTest do
  use Wik.DataCase, async: false

  import ExUnit.CaptureLog
  import Wik.TestGenerators

  alias Wik.Accounts.Membership
  alias Wik.Events.ExternalCalendar
  alias Wik.Events.ExternalCalendar.Fetch
  alias Wik.Events.ExternalCalendarSubscription
  alias Wik.Events.ExternalEvent
  alias Wik.Repo
  alias Wik.Scope

  test "Google Calendar UTC timestamps keep the calendar presentation timezone" do
    ics = tance_na_barce_ics(~D[2026-08-23])

    assert {:ok, calendar_data} =
             Fetch.parse_calendar(
               %{custom_name: nil, cached_name: nil, ics_url: "local"},
               ics,
               nil
             )

    parsed_event =
      Enum.find(calendar_data.calendar.events, &(&1.summary == "Tańce Na Barce"))

    assert parsed_event.dtstart == ~U[2026-08-23 16:00:00Z]
    assert parsed_event.dtend == ~U[2026-08-23 20:00:00Z]
    assert calendar_data.calendar.default_timezone == "Europe/Warsaw"

    assert DateTime.to_time(DateTime.shift_zone!(parsed_event.dtstart, "Europe/Warsaw")) ==
             ~T[18:00:00]

    assert DateTime.to_time(DateTime.shift_zone!(parsed_event.dtend, "Europe/Warsaw")) ==
             ~T[22:00:00]

    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, subscription} =
      ExternalCalendarSubscription.create(
        %{ics_url: "https://calendar.example.test/tance-na-barce.ics"},
        scope: scope(owner, space)
      )

    future_date = future_date(30)

    assert {:ok, _subscription} =
             ExternalCalendar.sync_subscription(subscription,
               http_get: fn _url, _opts ->
                 {:ok, %Req.Response{status: 200, body: tance_na_barce_ics(future_date)}}
               end
             )

    external_event = Repo.get_by!(ExternalEvent, title: "Tańce Na Barce")
    local_start = DateTime.shift_zone!(external_event.starts_at, external_event.tz)
    local_end = DateTime.shift_zone!(external_event.ends_at, external_event.tz)

    assert external_event.tz == "Europe/Warsaw"
    assert DateTime.to_date(local_start) == future_date

    expected_local_start =
      future_date
      |> DateTime.new!(~T[16:00:00], "Etc/UTC")
      |> DateTime.shift_zone!("Europe/Warsaw")
      |> DateTime.to_time()

    expected_local_end =
      future_date
      |> DateTime.new!(~T[20:00:00], "Etc/UTC")
      |> DateTime.shift_zone!("Europe/Warsaw")
      |> DateTime.to_time()

    assert Time.compare(DateTime.to_time(local_start), expected_local_start) == :eq
    assert Time.compare(DateTime.to_time(local_end), expected_local_end) == :eq
  end

  test "syncs floating timestamps in the calendar timezone" do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, subscription} =
      ExternalCalendarSubscription.create(
        %{ics_url: "https://calendar.example.test/floating.ics"},
        scope: scope(owner, space)
      )

    assert {:ok, _subscription} =
             ExternalCalendar.sync_subscription(subscription,
               http_get: fn _url, _opts ->
                 {:ok, %Req.Response{status: 200, body: floating_event_ics()}}
               end
             )

    external_event = Repo.get_by!(ExternalEvent, external_uid: "floating-event")
    local_start = DateTime.shift_zone!(external_event.starts_at, external_event.tz)

    assert external_event.tz == "Europe/Warsaw"
    assert DateTime.to_time(local_start) == ~T[18:00:00.000000]
  end

  test "skips ICS events without a start date" do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, subscription} =
      ExternalCalendarSubscription.create(
        %{ics_url: "https://calendar.example.test/mixed.ics"},
        scope: scope(owner, space)
      )

    log =
      capture_log(fn ->
        assert {:ok, _subscription} =
                 ExternalCalendar.sync_subscription(subscription,
                   http_get: fn _url, _opts ->
                     {:ok, %Req.Response{status: 200, body: mixed_schedule_ics()}}
                   end
                 )
      end)

    events = Repo.all(ExternalEvent)

    assert length(events) == 1
    assert List.first(events).external_uid == "scheduled-event"
    assert log =~ "Skipped unscheduled ICS event"
    assert log =~ "unscheduled-event"
  end

  test "stale space refresh skips fresh subscriptions" do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    scope = scope(owner, space)

    {:ok, _subscription} =
      ExternalCalendarSubscription.create(
        %{
          ics_url: "https://calendar.example.test/fresh.ics",
          cached_at: DateTime.utc_now()
        },
        scope: scope
      )

    assert :ok =
             Wik.Events.ExternalCalendar.StaleRefresh.refresh_space(scope,
               http_get: fn _url, _opts -> flunk("fresh subscription was refreshed") end
             )
  end

  test "stale space refresh fetches old subscriptions" do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    scope = scope(owner, space)

    {:ok, subscription} =
      ExternalCalendarSubscription.create(
        %{
          ics_url: "https://calendar.example.test/stale.ics",
          cached_at: DateTime.add(DateTime.utc_now(), -2, :hour)
        },
        scope: scope
      )

    assert :ok =
             Wik.Events.ExternalCalendar.StaleRefresh.refresh_space(scope,
               http_get: fn "https://calendar.example.test/stale.ics", _opts ->
                 {:ok, %Req.Response{status: 200, body: scheduled_event_ics()}}
               end
             )

    updated_subscription = Ash.get!(ExternalCalendarSubscription, subscription.id, scope: scope)
    assert DateTime.compare(updated_subscription.cached_at, subscription.cached_at) == :gt

    assert [%ExternalEvent{external_uid: "scheduled-event"}] = Repo.all(ExternalEvent)
  end

  test "stale space refresh uses etag and treats 304 as refreshed" do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    scope = scope(owner, space)
    cached_at = DateTime.add(DateTime.utc_now(), -2, :hour)

    {:ok, subscription} =
      ExternalCalendarSubscription.create(
        %{
          ics_url: "https://calendar.example.test/unchanged.ics",
          cached_at: cached_at,
          etag: ~s("abc")
        },
        scope: scope
      )

    assert :ok =
             Wik.Events.ExternalCalendar.StaleRefresh.refresh_space(scope,
               http_get: fn "https://calendar.example.test/unchanged.ics", opts ->
                 assert opts == [headers: [{"if-none-match", ~s("abc")}]]
                 {:ok, %Req.Response{status: 304}}
               end
             )

    updated_subscription = Ash.get!(ExternalCalendarSubscription, subscription.id, scope: scope)
    assert DateTime.compare(updated_subscription.cached_at, cached_at) == :gt
  end

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false
    )
  end

  defp scope(actor, tenant), do: %Scope{actor: actor, tenant: tenant}

  defp mixed_schedule_ics do
    """
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:-//Wik//External Calendar Sync Test//EN
    BEGIN:VEVENT
    UID:unscheduled-event
    DTSTAMP:20260529T120000Z
    SUMMARY:Unscheduled event
    END:VEVENT
    BEGIN:VEVENT
    UID:scheduled-event
    DTSTAMP:20260529T120000Z
    DTSTART:#{future_date_compact()}T180000Z
    DTEND:#{future_date_compact()}T200000Z
    SUMMARY:Scheduled event
    END:VEVENT
    END:VCALENDAR
    """
  end

  defp scheduled_event_ics do
    """
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:-//Wik//External Calendar Sync Test//EN
    BEGIN:VEVENT
    UID:scheduled-event
    DTSTAMP:20260529T120000Z
    DTSTART:#{future_date_compact()}T180000Z
    DTEND:#{future_date_compact()}T200000Z
    SUMMARY:Scheduled event
    END:VEVENT
    END:VCALENDAR
    """
  end

  defp floating_event_ics do
    """
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:-//Wik//External Calendar Sync Test//EN
    X-WR-TIMEZONE:Europe/Warsaw
    BEGIN:VEVENT
    UID:floating-event
    DTSTAMP:20260529T120000Z
    DTSTART:#{future_date_compact()}T180000
    DTEND:#{future_date_compact()}T200000
    SUMMARY:Floating event
    END:VEVENT
    END:VCALENDAR
    """
  end

  defp tance_na_barce_ics(date) do
    """
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:-//Google Inc//Google Calendar 70.9054//EN
    X-WR-TIMEZONE:Europe/Warsaw
    BEGIN:VEVENT
    UID:6go3ephn75gj8b9l69j6cb9k75i34bb268qm2b9l6gpjadhoc5hm2pb4cg@google.com
    DTSTAMP:20260818T094553Z
    DTSTART:#{compact(date)}T160000Z
    DTEND:#{compact(date)}T200000Z
    SUMMARY:Tańce Na Barce
    END:VEVENT
    END:VCALENDAR
    """
  end

  defp future_date_compact do
    30
    |> future_date()
    |> compact()
  end

  defp compact(date), do: date |> Date.to_iso8601() |> String.replace("-", "")
end
