defmodule WikWeb.EventsLive.TimelineData do
  alias Ash.Query
  alias Wik.Events
  alias Wik.Events.EventPublication
  alias Wik.Events.ExternalCalendar

  def load(scope) do
    publications_query =
      EventPublication
      |> Query.sort([{"event.starts_at", :asc}, {:inserted_at, :asc}])
      |> Query.load([:published_by, :space, event: [:author, :space]])

    with {:ok, space} <-
           Ash.load(scope.tenant, [event_publications: publications_query], scope: scope),
         {:ok, subscriptions} <-
           Ash.read(Events.external_calendar_subscriptions_query(), scope: scope) do
      loaded_subscriptions = ExternalCalendar.load_subscriptions(subscriptions)

      {:ok,
       %{
         internal_publications: space.event_publications,
         external_items: loaded_subscriptions.events,
         subscription_records: loaded_subscriptions.records,
         subscription_errors_by_id: loaded_subscriptions.errors_by_id,
         subscription_names_by_id: loaded_subscriptions.names_by_id
       }}
    end
  end

  def timeline_items(internal_publications, external_items, source) do
    (Enum.map(internal_publications, &normalize_internal_publication/1) ++ external_items)
    |> maybe_filter_items(source)
    |> Enum.sort_by(&{DateTime.to_unix(&1.starts_at, :microsecond), &1.id})
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

  defp normalize_internal_publication(publication) do
    event = publication.event

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
      calendar_name: nil,
      source_url: nil,
      subscription_id: nil
    }
  end

  defp maybe_filter_items(items, "internal"),
    do: Enum.filter(items, &(&1.source_type == :internal))

  defp maybe_filter_items(items, "external"),
    do: Enum.filter(items, &(&1.source_type == :external))

  defp maybe_filter_items(items, _source), do: items

  defp month_label(year, month) do
    year
    |> Date.new!(month, 1)
    |> Calendar.strftime("%B")
  end

  defp day_label(date) do
    Calendar.strftime(date, "%A %-d")
  end
end
