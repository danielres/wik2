defmodule WikWeb.EventsLive.TimelinePresenter do
  alias Wik.Events.ExternalCalendar

  def build(loaded_data, show_external?) do
    loaded_subscriptions = ExternalCalendar.load_subscriptions(loaded_data.subscription_records)

    internal_items =
      normalize_internal_publications(
        loaded_data.internal_publications,
        loaded_data.author_memberships_by_user_id
      )

    external_items =
      normalize_external_events(loaded_data.external_events, loaded_subscriptions)

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

  def timeline_items(internal_items, external_items, show_external?) do
    items =
      if show_external? do
        internal_items ++ external_items
      else
        internal_items
      end

    Enum.sort_by(items, &{DateTime.to_unix(&1.starts_at, :microsecond), &1.id})
  end

  def grouped_timeline_items(items) do
    items
    |> Enum.group_by(&DateTime.to_date(&1.starts_at).year)
    |> Enum.sort_by(fn {year, _items} -> year end)
    |> Enum.map(fn {year, year_items} ->
      %{
        year: year,
        months:
          year_items
          |> Enum.group_by(&DateTime.to_date(&1.starts_at).month)
          |> Enum.sort_by(fn {month, _items} -> month end)
          |> Enum.map(fn {month, month_items} ->
            %{
              month: month,
              label: month_label(year, month),
              days:
                month_items
                |> Enum.group_by(&DateTime.to_date(&1.starts_at))
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

  defp normalize_internal_publications(publications, author_memberships_by_user_id) do
    Enum.map(publications, &normalize_internal_publication(&1, author_memberships_by_user_id))
  end

  defp normalize_internal_publication(publication, author_memberships_by_user_id) do
    event = publication.event
    membership = Map.get(author_memberships_by_user_id, event.author.id)

    %{
      id: "internal:#{publication.id}",
      source_type: :internal,
      title: event.title,
      starts_at: event.starts_at,
      ends_at: event.ends_at,
      all_day: event.all_day,
      tz: event.tz,
      status: event.status,
      location: event.location,
      description: event.description,
      publication_id: publication.id,
      publication_type: publication.publication_type,
      event_url: nil,
      external_uid: nil,
      space_slug: publication.space.slug,
      source_name: publication.space.name,
      author_name: publication.event.author |> to_string(),
      author_user: publication.event.author,
      author_avatar_url: membership && membership.avatar_url,
      calendar_name: nil,
      source_url: nil,
      subscription_id: nil
    }
  end

  defp normalize_external_events(events, loaded_subscriptions) do
    subscription_by_id = Map.new(loaded_subscriptions.records, &{&1.id, &1})

    Enum.map(events, fn event ->
      subscription = Map.get(subscription_by_id, event.subscription_id)
      calendar_name = resolved_calendar_name(event, subscription, loaded_subscriptions)

      normalize_external_event(event, calendar_name)
    end)
  end

  defp normalize_external_event(event, calendar_name) do
    %{
      id: "external:#{event.id}",
      source_type: :external,
      title: event.title,
      starts_at: event.starts_at,
      ends_at: event.ends_at,
      all_day: event.all_day,
      tz: event.tz,
      status: event.status,
      location: event.location,
      description: event.description,
      publication_id: nil,
      publication_type: nil,
      event_url: event.event_url,
      external_uid: event.external_uid,
      external_recurrence_id: event.external_recurrence_id,
      space_slug: nil,
      source_name: nil,
      author_name: nil,
      author_user: nil,
      author_avatar_url: nil,
      calendar_name: calendar_name,
      source_url: nil,
      subscription_id: event.subscription_id
    }
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
