defmodule WikWeb.EventsLive.TimelineLoader do
  require Ash.Query

  alias Ash.Query
  alias Utils.Tz
  alias Wik.Accounts
  alias Wik.Events
  alias Wik.Events.ExternalCalendar
  alias Wik.Events.ExternalCalendarSubscription
  alias Wik.Events.EventPublication
  alias Wik.Tags
  alias Wik.Tags.Tagging
  alias WikWeb.EventsLive.TimelinePresenter

  @future_window_months 2

  def load(scope, opts \\ []) do
    show_external? = Keyword.get(opts, :show_external?, false)
    future_windows = Keyword.get(opts, :future_windows, 1)
    yesterday_start = Date.utc_today() |> Date.add(-1) |> DateTime.new!(~T[00:00:00], "Etc/UTC")

    publications_query =
      EventPublication
      |> Events.scheduled_event_publications_query()
      |> Query.filter(
        event.starts_at >= ^yesterday_start or
          (not is_nil(event.ends_at) and event.ends_at >= ^yesterday_start)
      )
      |> Query.sort([{"event.starts_at", :asc}, {:inserted_at, :asc}])
      |> Query.load([
        :published_by,
        :space,
        event: [:author, :space]
      ])

    with {:ok, space} <-
           Ash.load(scope.tenant, [event_publications: publications_query], scope: scope),
         publications = upcoming_publications(space.event_publications),
         {:ok, author_memberships_by_user_id} <-
           load_author_memberships_by_user_id(publications),
         {:ok, current_membership} <-
           Accounts.get_membership(scope.tenant.id, scope.actor.id),
         {:ok, participations_by_publication_id} <-
           load_participations_by_publication_id(publications, scope),
         {:ok, subscriptions} <-
           Ash.read(Events.external_calendar_subscriptions_query(), scope: scope),
         {:ok, taggings_by_subscription_id} <-
           load_taggings_by_subscription_id(subscriptions, scope),
         {:ok, space_tags} <- Tags.list_space_tags(scope),
         {:ok, external_events} <- read_external_events(scope, future_windows),
         {:ok, participations_by_external_event_id} <-
           load_participations_by_external_event_id(external_events, scope) do
      {:ok,
       %{
         internal_publications: publications,
         author_memberships_by_user_id: author_memberships_by_user_id,
         current_membership: current_membership,
         participations_by_publication_id: participations_by_publication_id,
         participations_by_external_event_id: participations_by_external_event_id,
         subscription_records: subscriptions,
         space_tags: space_tags,
         taggings_by_subscription_id: taggings_by_subscription_id,
         external_events: external_events,
         more_external_future?: more_external_future?(scope, show_external?, future_windows)
       }}
    end
  end

  def load_external_items([], _scope), do: {:ok, []}

  def load_external_items(external_events, scope) when is_list(external_events) do
    with {:ok, current_membership} <-
           Accounts.get_membership(scope.tenant.id, scope.actor.id),
         {:ok, subscriptions} <- load_external_event_subscriptions(external_events, scope),
         {:ok, taggings_by_subscription_id} <-
           load_taggings_by_subscription_id(subscriptions, scope),
         {:ok, participations_by_external_event_id} <-
           load_participations_by_external_event_id(external_events, scope) do
      loaded_subscriptions = ExternalCalendar.load_subscriptions(subscriptions)

      {:ok,
       TimelinePresenter.external_items(
         external_events,
         loaded_subscriptions,
         participations_by_external_event_id,
         current_membership,
         taggings_by_subscription_id
       )}
    end
  end

  defp load_taggings_by_subscription_id([], _scope), do: {:ok, %{}}

  defp load_taggings_by_subscription_id(subscriptions, scope) do
    subscription_ids = Enum.map(subscriptions, & &1.id)

    Tagging
    |> Query.filter(
      taggable_type == "external_calendar_subscription" and taggable_id in ^subscription_ids
    )
    |> Query.load([:tag])
    |> Ash.read(scope: scope)
    |> case do
      {:ok, taggings} -> {:ok, Enum.group_by(taggings, & &1.taggable_id)}
      {:error, error} -> {:error, error}
    end
  end

  defp load_external_event_subscriptions(external_events, scope) do
    subscription_ids =
      external_events
      |> Enum.map(& &1.subscription_id)
      |> Enum.uniq()

    ExternalCalendarSubscription
    |> Query.filter(id in ^subscription_ids)
    |> Query.load(:space)
    |> Ash.read(scope: scope)
  end

  defp upcoming_publications(publications) do
    Enum.filter(publications, fn publication ->
      event = publication.event
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

  defp load_participations_by_external_event_id([], _scope), do: {:ok, %{}}

  defp load_participations_by_external_event_id(external_events, scope) do
    external_event_ids = Enum.map(external_events, & &1.id)

    external_event_ids
    |> Events.external_event_participations_query()
    |> Ash.read(scope: scope)
    |> case do
      {:ok, participations} -> {:ok, Enum.group_by(participations, & &1.external_event_id)}
      {:error, error} -> {:error, error}
    end
  end

  defp load_participations_by_publication_id([], _scope), do: {:ok, %{}}

  defp load_participations_by_publication_id(publications, scope) do
    publication_ids = Enum.map(publications, & &1.id)

    publication_ids
    |> Events.event_participations_query()
    |> Ash.read(scope: scope)
    |> case do
      {:ok, participations} -> {:ok, Enum.group_by(participations, & &1.publication_id)}
      {:error, error} -> {:error, error}
    end
  end

  defp load_author_memberships_by_user_id([]), do: {:ok, %{}}

  defp load_author_memberships_by_user_id(publications) do
    space_id = publications |> List.first() |> then(& &1.space.id)

    user_ids =
      publications
      |> Enum.map(& &1.event.author.id)
      |> Enum.uniq()

    Accounts.list_memberships_by_user_id(space_id, user_ids)
  end

  defp read_external_events(scope, future_windows) do
    future_window_end = future_window_end(future_windows)

    query =
      Events.upcoming_external_events_query(until: future_window_end)

    case Ash.read(query, scope: scope) do
      {:ok, events} -> {:ok, events}
      {:error, error} -> {:error, error}
    end
  end

  defp more_external_future?(_scope, false, _future_windows), do: false

  defp more_external_future?(scope, true, future_windows) do
    future_window_end = future_window_end(future_windows)

    query =
      Events.external_events_query()
      |> Events.scheduled_external_events_query()
      |> Query.filter(starts_at > ^future_window_end)
      |> Query.limit(1)

    case Ash.read(query, scope: scope) do
      {:ok, []} -> false
      {:ok, [_ | _]} -> true
      {:error, _error} -> false
    end
  end

  defp future_window_end(future_windows) do
    Date.utc_today()
    |> Date.shift(month: future_windows * @future_window_months)
    |> DateTime.new!(~T[23:59:59], "Etc/UTC")
  end
end
