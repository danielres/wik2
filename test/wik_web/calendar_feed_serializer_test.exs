defmodule Wik.Events.Feeds.SerializerTest do
  use ExUnit.Case, async: true

  alias Wik.Events.Event
  alias Wik.Events.EventPublication
  alias Wik.Events.ExternalEvent
  alias Wik.Events.Feeds.Serializer

  test "serializes timed events with the event timezone" do
    ics =
      timed_event()
      |> then(&Serializer.to_ics([&1], calendar_name: "Timed feed"))

    assert ics =~ "BEGIN:VCALENDAR"
    assert ics =~ "X-WR-CALNAME:Timed feed"
    assert ics =~ "SUMMARY:Berlin dinner"
    assert ics =~ "DTSTART;TZID=Europe/Berlin:20260510T200000"
    assert ics =~ "DTEND;TZID=Europe/Berlin:20260510T220000"
    assert ics =~ "STATUS:CONFIRMED"
  end

  test "serializes all-day events as date values" do
    ics =
      all_day_event()
      |> then(&Serializer.to_ics([&1], calendar_name: "All-day feed"))

    assert ics =~ "DTSTART;VALUE=DATE:20260515"
    assert ics =~ "DTEND;VALUE=DATE:20260516"
  end

  test "serializes cancelled events as cancelled" do
    ics =
      cancelled_event()
      |> then(&Serializer.to_ics([&1], calendar_name: "Cancelled feed"))

    assert ics =~ "STATUS:CANCELLED"
  end

  test "serializes timed events without an end time without crashing" do
    ics =
      timed_event()
      |> Map.put(:ends_at, nil)
      |> then(&Serializer.to_ics([&1], calendar_name: "Timed feed"))

    assert ics =~ "BEGIN:VCALENDAR"
    refute ics =~ "DTEND"
  end

  test "serializes aggregate visibility context in the description" do
    ics =
      %{
        event: timed_event_with_space(),
        publications: [
          %EventPublication{
            event: timed_event_with_space(),
            space: %Wik.Accounts.Space{name: "berlin-hackers"},
            publication_type: :origin
          },
          %EventPublication{
            event: timed_event_with_space(),
            space: %Wik.Accounts.Space{name: "community-kitchen"},
            publication_type: :relay,
            published_by: %Wik.Accounts.User{email: "ada@example.com"},
            relay_note: "Worth sharing"
          }
        ]
      }
      |> then(&Serializer.to_ics([&1], calendar_name: "Aggregate feed"))

    assert ics =~ "DESCRIPTION:Bring food\\n\\nVisible in: berlin-hackers"
    assert ics =~ "Visible in: community-kitchen"
    assert ics =~ "Relay note: Worth sharing"
  end

  test "serializes aggregate external event entries" do
    ics =
      %{external_event: external_event(), participations: []}
      |> then(&Serializer.to_ics([&1], calendar_name: "Aggregate feed"))

    assert ics =~ "SUMMARY:External dinner"
    assert ics =~ "DESCRIPTION:Imported from an external calendar"
    assert ics =~ "DTSTART:20260603T180000Z"
    assert ics =~ "DTEND:20260603T200000Z"
  end

  defp timed_event do
    %Event{
      description: "Bring food",
      ends_at: ~U[2026-05-10 20:00:00Z],
      id: "event-1",
      inserted_at: ~U[2026-05-01 09:00:00Z],
      location: "Community Hall",
      starts_at: ~U[2026-05-10 18:00:00Z],
      status: :published,
      title: "Berlin dinner",
      tz: "Europe/Berlin",
      updated_at: ~U[2026-05-02 09:00:00Z]
    }
  end

  defp timed_event_with_space do
    %{timed_event() | space: %Wik.Accounts.Space{name: "origin-space"}}
  end

  defp all_day_event do
    %Event{
      all_day: true,
      description: "Workshops all day",
      ends_at: ~U[2026-05-15 21:59:59Z],
      id: "event-2",
      inserted_at: ~U[2026-05-01 09:00:00Z],
      location: "Town Hall",
      starts_at: ~U[2026-05-14 22:00:00Z],
      status: :published,
      title: "Festival",
      tz: "Europe/Berlin",
      updated_at: ~U[2026-05-02 09:00:00Z]
    }
  end

  defp external_event do
    %ExternalEvent{
      all_day: false,
      description: "Imported from an external calendar",
      ends_at: ~U[2026-06-03 20:00:00Z],
      id: "external-event-1",
      inserted_at: ~U[2026-06-01 09:00:00Z],
      location: "Riverside Hall",
      starts_at: ~U[2026-06-03 18:00:00Z],
      status: :published,
      title: "External dinner",
      tz: "Etc/UTC",
      updated_at: ~U[2026-06-02 09:00:00Z]
    }
  end

  defp cancelled_event do
    %Event{
      description: "Cancelled",
      ends_at: ~U[2026-05-10 20:00:00Z],
      id: "event-3",
      inserted_at: ~U[2026-05-01 09:00:00Z],
      location: "Community Hall",
      starts_at: ~U[2026-05-10 18:00:00Z],
      status: :cancelled,
      title: "Cancelled dinner",
      tz: "Etc/UTC",
      updated_at: ~U[2026-05-02 09:00:00Z]
    }
  end
end
