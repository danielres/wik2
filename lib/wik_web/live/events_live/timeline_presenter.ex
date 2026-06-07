defmodule WikWeb.EventsLive.TimelinePresenter do
  alias Utils.Tz
  alias Wik.Accounts
  alias Wik.Events.ExternalCalendar
  alias WikWeb.EventsLive.TimelineEvent

  def build(loaded_data, show_external?) do
    loaded_subscriptions = ExternalCalendar.load_subscriptions(loaded_data.subscription_records)

    internal_items =
      normalize_internal_publications(
        loaded_data.internal_publications,
        loaded_data.author_memberships_by_user_id,
        loaded_data.participations_by_publication_id,
        loaded_data.current_membership
      )

    external_items =
      normalize_external_events(
        loaded_data.external_events,
        loaded_subscriptions,
        loaded_data.internal_publications
      )

    items = timeline_items(internal_items, external_items, show_external?)

    %{
      internal_publications: loaded_data.internal_publications,
      internal_items: internal_items,
      external_items: external_items,
      items: items,
      grouped_items: grouped_timeline_items(items),
      more_external_future?: loaded_data.more_external_future?,
      subscription_records: loaded_subscriptions.records,
      subscription_errors_by_id: loaded_subscriptions.errors_by_id,
      subscription_names_by_id: loaded_subscriptions.names_by_id,
      subscription_metadata_by_id: loaded_subscriptions.metadata_by_id
    }
  end

  def internal_item(publication, membership, participations \\ [], current_membership \\ nil) do
    local_event = publication.event
    event = TimelineEvent.resolve(local_event)

    %{
      id: "internal:#{publication.id}",
      source_type: :internal,
      event: event,
      local_event: local_event,
      publication: publication,
      event_url: nil,
      external_uid: nil,
      external_recurrence_id: nil,
      space_slug: publication.space.slug,
      source_name: publication.space.name,
      author: Accounts.present_membership(membership),
      calendar_name: nil,
      current_member_participation:
        current_member_participation(participations, current_membership),
      participations: participations,
      source_url: nil,
      subscription_id: nil
    }
  end

  def timeline_items(internal_items, external_items, show_external?) do
    items =
      if show_external? do
        internal_items ++ external_items
      else
        internal_items
      end

    Enum.sort_by(items, &{DateTime.to_unix(&1.event.starts_at, :microsecond), &1.id})
  end

  def grouped_timeline_items(items) do
    items
    |> Enum.group_by(&extract_event_local_start_date(&1).year)
    |> Enum.sort_by(fn {year, _items} -> year end)
    |> Enum.map(fn {year, year_items} ->
      %{
        year: year,
        months:
          year_items
          |> Enum.group_by(&extract_event_local_start_date(&1).month)
          |> Enum.sort_by(fn {month, _items} -> month end)
          |> Enum.map(fn {month, month_items} ->
            %{
              month: month,
              label: month_label(year, month),
              days:
                month_items
                |> Enum.group_by(&extract_event_local_start_date/1)
                |> Enum.sort_by(fn {date, _items} -> date end)
                |> Enum.map(fn {date, day_items} ->
                  %{
                    day: date.day,
                    label: day_label(date),
                    items: day_items
                  }
                end)
            }
          end)
      }
    end)
  end

  defp extract_event_local_start_date(%{event: event}) do
    event.starts_at
    |> Tz.to_local!(event.tz || "Etc/UTC")
    |> DateTime.to_date()
  end

  defp normalize_internal_publications(
         publications,
         author_memberships_by_user_id,
         participations_by_publication_id,
         current_membership
       ) do
    Enum.map(
      publications,
      &normalize_internal_publication(
        &1,
        author_memberships_by_user_id,
        participations_by_publication_id,
        current_membership
      )
    )
  end

  defp normalize_internal_publication(
         publication,
         author_memberships_by_user_id,
         participations_by_publication_id,
         current_membership
       ) do
    event = publication.event
    membership = Map.get(author_memberships_by_user_id, event.author.id)
    participations = Map.get(participations_by_publication_id, publication.id, [])

    internal_item(publication, membership, participations, current_membership)
  end

  defp normalize_external_events(events, loaded_subscriptions, internal_publications) do
    subscription_by_id = Map.new(loaded_subscriptions.records, &{&1.id, &1})
    linked_external_event_ids = linked_external_event_ids(internal_publications)

    events
    |> Enum.reject(&MapSet.member?(linked_external_event_ids, &1.id))
    |> Enum.map(fn event ->
      subscription = Map.get(subscription_by_id, event.subscription_id)
      calendar_name = resolved_calendar_name(event, subscription, loaded_subscriptions)

      normalize_external_event(event, calendar_name)
    end)
  end

  defp normalize_external_event(event, calendar_name) do
    %{
      id: "external:#{event.id}",
      source_type: :external,
      event: event,
      publication: nil,
      event_url: event.event_url,
      external_uid: event.external_uid,
      external_recurrence_id: event.external_recurrence_id,
      space_slug: nil,
      source_name: nil,
      author: nil,
      calendar_name: calendar_name,
      current_member_participation: nil,
      participations: [],
      source_url: nil,
      subscription_id: event.subscription_id
    }
  end

  defp linked_external_event_ids(publications) do
    publications
    |> Enum.map(& &1.event.source_external_event_id)
    |> Enum.reject(&is_nil/1)
    |> MapSet.new()
  end

  defp current_member_participation(_participations, nil), do: nil

  defp current_member_participation(participations, current_membership) do
    Enum.find(participations, &(&1.membership_id == current_membership.id))
  end

  defp month_label(year, month) do
    year
    |> Date.new!(month, 1)
    |> Calendar.strftime("%B")
  end

  defp day_label(date) do
    Calendar.strftime(date, "%A %-d")
  end

  defp resolved_calendar_name(event, nil, _loaded_subscriptions), do: event.calendar_name

  defp resolved_calendar_name(event, subscription, loaded_subscriptions) do
    ExternalCalendar.display_name(
      subscription,
      Map.get(loaded_subscriptions.names_by_id, subscription.id, event.calendar_name)
    )
  end
end
