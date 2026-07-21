defmodule Wik.Events.ExternalCalendarSyncTest do
  use Wik.DataCase, async: false

  import ExUnit.CaptureLog
  import Wik.TestGenerators

  alias Wik.Accounts.Membership
  alias Wik.Events.ExternalCalendar
  alias Wik.Events.ExternalCalendarSubscription
  alias Wik.Events.ExternalEvent
  alias Wik.Repo
  alias Wik.Scope

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

  defp future_date_compact do
    30
    |> future_date()
    |> Date.to_iso8601()
    |> String.replace("-", "")
  end
end
