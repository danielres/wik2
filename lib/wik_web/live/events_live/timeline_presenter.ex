defmodule WikWeb.EventsLive.TimelinePresenter do
  alias Utils.Tz
  alias Wik.Accounts
  alias Wik.Events.ExternalCalendar

  def aggregate_items(entries, user, opts \\ []) do
    internal_publications = aggregate_internal_publications(entries)

    author_memberships_by_space_and_user =
      author_memberships_by_space_and_user(internal_publications)

    entries
    |> Enum.map(&aggregate_item(&1, user, author_memberships_by_space_and_user))
    |> Enum.reject(&is_nil/1)
    |> maybe_filter_upcoming(Keyword.get(opts, :upcoming?, false))
    |> Enum.sort_by(&{DateTime.to_unix(&1.event.starts_at, :microsecond), &1.id})
  end

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
        loaded_data.participations_by_external_event_id,
        loaded_data.current_membership
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

    %{
      id: "internal:#{publication.id}",
      source_type: :internal,
      event: local_event,
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
    visible_external_items =
      if show_external? do
        external_items
      else
        Enum.reject(external_items, &(&1.participations == []))
      end

    items = internal_items ++ visible_external_items

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

  defp aggregate_internal_publications(entries) do
    entries
    |> Enum.filter(&Map.has_key?(&1, :publications))
    |> Enum.map(&List.first(&1.publications))
    |> Enum.reject(&is_nil/1)
  end

  defp aggregate_item(%{event: event, publications: publications} = entry, user, memberships) do
    with publication when not is_nil(publication) <- origin_publication(publications) do
      item =
        internal_item(
          publication,
          Map.get(memberships, {publication.space.id, event.author.id}),
          Map.get(entry, :participations, [])
        )

      %{
        item
        | current_member_participation:
            current_member_participation_by_user(Map.get(entry, :participations, []), user)
      }
      |> Map.put(:open_path, "/#{publication.space.slug}/events?event=#{event.id}")
    end
  end

  defp aggregate_item(%{external_event: event} = entry, user, _memberships) do
    normalize_external_event(
      event,
      external_calendar_name(event),
      Map.get(entry, :participations, []),
      nil
    )
    |> Map.put(:space_slug, entry.space.slug)
    |> Map.put(:source_name, entry.space.name)
    |> Map.put(:open_path, "/#{entry.space.slug}/events?ext=#{event.id}")
    |> Map.put(
      :current_member_participation,
      current_member_participation_by_user(Map.get(entry, :participations, []), user)
    )
  end

  defp origin_publication(publications) do
    Enum.find(publications, &(&1.publication_type == :origin)) || List.first(publications)
  end

  defp maybe_filter_upcoming(items, false), do: items

  defp maybe_filter_upcoming(items, true) do
    Enum.filter(items, fn item ->
      event = item.event
      tz = event.tz || "Etc/UTC"

      event_date =
        (event.ends_at || event.starts_at)
        |> Tz.to_local!(tz)
        |> DateTime.to_date()

      today =
        DateTime.utc_now()
        |> Tz.to_local!(tz)
        |> DateTime.to_date()

      Date.compare(event_date, today) in [:eq, :gt]
    end)
  end

  defp author_memberships_by_space_and_user(publications) do
    publications
    |> Enum.group_by(& &1.space.id)
    |> Enum.reduce(%{}, fn {_space_id, space_publications}, acc ->
      space = List.first(space_publications).space
      user_ids = Enum.map(space_publications, & &1.event.author.id) |> Enum.uniq()

      case Accounts.list_memberships_by_user_id(space.id, user_ids) do
        {:ok, memberships_by_user_id} ->
          Enum.reduce(memberships_by_user_id, acc, fn {user_id, membership}, space_acc ->
            Map.put(space_acc, {space.id, user_id}, membership)
          end)

        {:error, _error} ->
          acc
      end
    end)
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

  defp normalize_external_events(
         events,
         loaded_subscriptions,
         participations_by_external_event_id,
         current_membership
       ) do
    subscription_by_id = Map.new(loaded_subscriptions.records, &{&1.id, &1})

    events
    |> Enum.map(fn event ->
      subscription = Map.get(subscription_by_id, event.subscription_id)
      calendar_name = resolved_calendar_name(event, subscription, loaded_subscriptions)
      participations = Map.get(participations_by_external_event_id, event.id, [])

      normalize_external_event(event, calendar_name, participations, current_membership)
    end)
  end

  defp normalize_external_event(event, calendar_name, participations, current_membership) do
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
      current_member_participation:
        current_member_participation(participations, current_membership),
      participations: participations,
      source_url: nil,
      subscription_id: event.subscription_id
    }
  end

  defp current_member_participation(_participations, nil), do: nil

  defp current_member_participation(participations, current_membership) do
    Enum.find(participations, &(&1.membership_id == current_membership.id))
  end

  defp current_member_participation_by_user(participations, user) do
    Enum.find(participations, fn participation ->
      participation.membership.user_id == user.id
    end)
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

  defp external_calendar_name(%{subscription: %Ash.NotLoaded{}} = event), do: event.calendar_name

  defp external_calendar_name(%{subscription: subscription} = event)
       when not is_nil(subscription) do
    ExternalCalendar.display_name(subscription, event.calendar_name)
  end

  defp external_calendar_name(event), do: event.calendar_name
end
