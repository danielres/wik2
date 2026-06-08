defmodule Wik.Events.Feeds.Serializer do
  alias Utils.Tz
  alias Wik.Accounts
  alias Wik.Events.Event
  alias Wik.Events.ExternalEvent
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

  defp to_ical_event(%{event: %Event{}, publications: _publications} = entry) do
    event = entry.event

    %ICal.Event{
      created: event.inserted_at,
      description: aggregate_description(entry),
      dtend: dtend(event),
      dtstamp: event.updated_at,
      dtstart: dtstart(event),
      location: blank_to_nil(event.location),
      status: event_status(event),
      summary: event.title,
      uid: event_uid(event)
    }
  end

  defp to_ical_event(%{external_event: %ExternalEvent{} = event} = entry) do
    %ICal.Event{
      created: event.inserted_at,
      description: aggregate_description(entry),
      dtend: dtend(event),
      dtstamp: event.updated_at,
      dtstart: dtstart(event),
      location: blank_to_nil(event.location),
      status: event_status(event),
      summary: event.title,
      uid: event_uid(event)
    }
  end

  defp dtstart(%{all_day: true, starts_at: starts_at, tz: tz}) do
    starts_at
    |> Tz.to_local!(tz)
    |> DateTime.to_date()
  end

  defp dtstart(%{starts_at: starts_at, tz: tz}) do
    Tz.to_local!(starts_at, tz)
  end

  defp dtend(%{all_day: true, ends_at: nil}), do: nil

  defp dtend(%{all_day: true, ends_at: ends_at, tz: tz}) do
    ends_at
    |> Tz.to_local!(tz)
    |> DateTime.to_date()
    |> Date.add(1)
  end

  defp dtend(%{all_day: false, ends_at: nil}), do: nil

  defp dtend(%{all_day: false, ends_at: ends_at, tz: tz}) do
    Tz.to_local!(ends_at, tz)
  end

  defp event_status(%{status: :cancelled}), do: :cancelled
  defp event_status(_event), do: :confirmed

  defp event_uid(%{id: event_id}) do
    uri = URI.parse(Endpoint.url())
    host = uri.host || "wik"

    "#{event_id}@#{host}"
  end

  defp aggregate_description(%{event: %Event{} = event, publications: publications} = entry) do
    top_section =
      top_section(event_url(event.space, event.id), Map.get(entry, :participations, []))

    [top_section, description_section(event.description), aggregate_context(publications)]
    |> Enum.reject(&blank?/1)
    |> Enum.join("\n\n---\n\n")
    |> blank_to_nil()
  end

  defp aggregate_description(%{external_event: %ExternalEvent{} = event} = entry) do
    top_section =
      top_section(external_event_url(entry.space, event.id), Map.get(entry, :participations, []))

    [top_section, description_section(event.description), aggregate_context([entry])]
    |> Enum.reject(&blank?/1)
    |> Enum.join("\n\n---\n\n")
    |> blank_to_nil()
  end

  defp top_section(url, participations) do
    ["View event: #{url}", participation_section(participations)]
    |> Enum.reject(&blank?/1)
    |> Enum.join("\n\n")
  end

  defp participation_section([]), do: nil

  defp participation_section(participations) do
    sorted_participations =
      Enum.sort_by(participations, fn participation ->
        {-participation.interest, participation_name(participation)}
      end)

    visible_participations =
      if length(sorted_participations) > 10 do
        Enum.take(sorted_participations, 9)
      else
        Enum.take(sorted_participations, 10)
      end

    lines =
      visible_participations
      |> Enum.map(&participation_line/1)
      |> maybe_append_more_participations(sorted_participations)

    "Participation/Interest:\n\n#{Enum.join(lines, "\n")}"
  end

  defp maybe_append_more_participations(lines, participations) do
    if length(participations) > 10, do: lines ++ ["- ..."], else: lines
  end

  defp participation_line(participation) do
    extra_info =
      participation.extra_info
      |> blank_to_nil()
      |> case do
        nil -> ""
        extra_info -> " - #{extra_info}"
      end

    "- #{participation_name(participation)}: #{participation.interest}/10#{extra_info}"
  end

  defp participation_name(%{membership: membership}) do
    membership
    |> Accounts.present_membership()
    |> Map.get(:display_name)
    |> blank_to_nil()
    |> case do
      nil -> "member"
      display_name -> display_name
    end
  end

  defp description_section(description) do
    case blank_to_nil(description) do
      nil -> nil
      description -> "Description:\n\n#{description}"
    end
  end

  defp aggregate_context(publications) do
    [visible_in_section(publications), relay_notes_section(publications)]
    |> Enum.reject(&blank?/1)
    |> Enum.join("\n\n")
  end

  defp visible_in_section(publications) do
    lines =
      publications
      |> Enum.map(& &1.space.name)
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.map(&"- #{&1}")

    "Visible in:\n#{Enum.join(lines, "\n")}"
  end

  defp relay_notes_section(publications) do
    lines =
      publications
      |> Enum.filter(&relay_note?/1)
      |> Enum.map(& &1.relay_note)
      |> Enum.uniq()
      |> Enum.join("\n")

    case blank_to_nil(lines) do
      nil -> nil
      lines -> "Relay note:\n#{lines}"
    end
  end

  defp relay_note?(%{publication_type: :relay, relay_note: relay_note})
       when relay_note not in [nil, ""] do
    true
  end

  defp relay_note?(_publication), do: false

  defp event_url(space, event_id) do
    "#{Endpoint.url()}/#{space.slug}/events?event=#{event_id}"
  end

  defp external_event_url(space, event_id) do
    "#{Endpoint.url()}/#{space.slug}/events?ext=#{event_id}"
  end

  defp blank?(value), do: blank_to_nil(value) == nil

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
