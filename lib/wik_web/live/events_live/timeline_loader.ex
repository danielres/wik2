defmodule WikWeb.EventsLive.TimelineLoader do
  require Ash.Query

  alias Ash.Query
  alias Utils.Tz
  alias Wik.Accounts
  alias Wik.Events
  alias Wik.Events.EventPublication

  @future_window_months 2

  def load(scope, opts \\ []) do
    show_external? = Keyword.get(opts, :show_external?, false)
    future_windows = Keyword.get(opts, :future_windows, 1)
    yesterday_start = Date.utc_today() |> Date.add(-1) |> DateTime.new!(~T[00:00:00], "Etc/UTC")

    publications_query =
      EventPublication
      |> Query.filter(
        (is_nil(event.source_external_event_id) and
           (event.starts_at >= ^yesterday_start or
              (not is_nil(event.ends_at) and event.ends_at >= ^yesterday_start))) or
          (not is_nil(event.source_external_event_id) and
             (event.source_external_event.starts_at >= ^yesterday_start or
                event.source_external_event.ends_at >= ^yesterday_start))
      )
      |> Query.sort([{"event.starts_at", :asc}, {:inserted_at, :asc}])
      |> Query.load([
        :published_by,
        :space,
        event: [:author, :space, source_external_event: [:subscription]]
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
         {:ok, external_events} <- read_external_events(scope, show_external?, future_windows) do
      {:ok,
       %{
         internal_publications: publications,
         author_memberships_by_user_id: author_memberships_by_user_id,
         current_membership: current_membership,
         participations_by_publication_id: participations_by_publication_id,
         subscription_records: subscriptions,
         external_events: external_events,
         more_external_future?: more_external_future?(scope, show_external?, future_windows)
       }}
    end
  end

  defp upcoming_publications(publications) do
    today = Date.utc_today()

    Enum.filter(publications, fn publication ->
      event = timeline_event(publication.event)

      event_date =
        (event.ends_at || event.starts_at)
        |> Tz.to_local!(event.tz || "Etc/UTC")
        |> DateTime.to_date()

      Date.compare(event_date, today) in [:eq, :gt]
    end)
  end

  defp timeline_event(%{source_external_event: %{id: _id} = external_event}), do: external_event
  defp timeline_event(event), do: event

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

  defp read_external_events(_scope, false, _future_windows), do: {:ok, []}

  defp read_external_events(scope, true, future_windows) do
    today_start = DateTime.new!(Date.utc_today(), ~T[00:00:00], "Etc/UTC")
    future_window_end = future_window_end(future_windows)

    query =
      Events.external_events_query()
      |> Query.filter(starts_at >= ^today_start and starts_at <= ^future_window_end)

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
