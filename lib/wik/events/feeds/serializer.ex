defmodule Wik.Events.Feeds.Serializer do
  alias Utils.Tz
  alias Wik.Events.Event
  alias WikWeb.Endpoint

  @vendor "Wik"

  def to_ics(events, opts) when is_list(events) do
    calendar_name = Keyword.fetch!(opts, :calendar_name)

    %ICal{
      custom_properties: calendar_properties(calendar_name),
      events: Enum.map(events, &to_ical_event/1)
    }
    |> ICal.set_vendor(@vendor)
    |> ICal.to_ics()
    |> IO.iodata_to_binary()
  end

  defp calendar_properties(calendar_name) do
    %{
      "NAME" => %{params: %{}, value: calendar_name},
      "X-WR-CALNAME" => %{params: %{}, value: calendar_name}
    }
  end

  defp to_ical_event(%Event{} = event) do
    %ICal.Event{
      created: event.inserted_at,
      description: blank_to_nil(event.description),
      dtend: dtend(event),
      dtstamp: event.updated_at,
      dtstart: dtstart(event),
      location: blank_to_nil(event.location),
      status: event_status(event),
      summary: event.title,
      uid: event_uid(event)
    }
  end

  defp to_ical_event(%{event: %Event{} = event, publications: publications}) do
    %ICal.Event{
      created: event.inserted_at,
      description: aggregate_description(event, publications),
      dtend: dtend(event),
      dtstamp: event.updated_at,
      dtstart: dtstart(event),
      location: blank_to_nil(event.location),
      status: event_status(event),
      summary: event.title,
      uid: event_uid(event)
    }
  end

  defp dtstart(%Event{all_day: true, starts_at: starts_at, tz: tz}) do
    starts_at
    |> Tz.to_local!(tz)
    |> DateTime.to_date()
  end

  defp dtstart(%Event{starts_at: starts_at, tz: tz}) do
    Tz.to_local!(starts_at, tz)
  end

  defp dtend(%Event{all_day: true, ends_at: nil}), do: nil

  defp dtend(%Event{all_day: true, ends_at: ends_at, tz: tz}) do
    ends_at
    |> Tz.to_local!(tz)
    |> DateTime.to_date()
    |> Date.add(1)
  end

  defp dtend(%Event{all_day: false, ends_at: nil}), do: nil

  defp dtend(%Event{all_day: false, ends_at: ends_at, tz: tz}) do
    Tz.to_local!(ends_at, tz)
  end

  defp event_status(%Event{status: :cancelled}), do: :cancelled
  defp event_status(%Event{}), do: :confirmed

  defp event_uid(%Event{id: event_id}) do
    uri = URI.parse(Endpoint.url())
    host = uri.host || "wik"

    "#{event_id}@#{host}"
  end

  defp aggregate_description(event, publications) do
    [blank_to_nil(event.description), aggregate_context(event, publications)]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n\n")
    |> blank_to_nil()
  end

  defp aggregate_context(event, publications) do
    publications
    |> Enum.flat_map(&publication_context_lines(event, &1))
    |> Enum.uniq()
    |> Enum.join("\n")
  end

  defp publication_context_lines(event, publication) do
    lines = ["Visible in: #{publication.group.name}"]

    if event.provenance_policy == :visible do
      lines
      |> maybe_append_origin_line(publication)
      |> maybe_append_relayed_by_line(publication)
      |> maybe_append_relay_note_line(publication)
    else
      lines
    end
  end

  defp maybe_append_origin_line(lines, %{publication_type: :origin, event: %{group: group}}) do
    lines ++ ["From: #{group.name}"]
  end

  defp maybe_append_origin_line(lines, %{publication_type: :relay, event: %{group: group}}) do
    lines ++ ["From: #{group.name}"]
  end

  defp maybe_append_relayed_by_line(lines, %{publication_type: :relay, published_by: published_by}) do
    lines ++ ["Relayed by: #{published_by}"]
  end

  defp maybe_append_relayed_by_line(lines, _publication), do: lines

  defp maybe_append_relay_note_line(lines, %{publication_type: :relay, relay_note: relay_note})
       when relay_note not in [nil, ""] do
    lines ++ ["Relay note: #{relay_note}"]
  end

  defp maybe_append_relay_note_line(lines, _publication), do: lines

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
