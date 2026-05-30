defmodule Wik.Events do
  use Ash.Domain,
    otp_app: :wik,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  import Ecto.Query, only: [from: 2]
  require Ash.Expr
  require Ash.Query

  alias Ash.Query
  alias Wik.Accounts.Space
  alias Wik.Events.Event
  alias Wik.Events.ExternalCalendarSubscription
  alias Wik.Events.EventPublication
  alias Wik.Events.EventPublication.Checks
  alias Wik.Events.Feeds
  alias Wik.Repo

  admin do
    show? true
  end

  resources do
    resource Event
    resource EventPublication
    resource ExternalCalendarSubscription
  end

  def external_calendar_subscriptions_query do
    ExternalCalendarSubscription
    |> Query.sort(inserted_at: :asc)
    |> Query.load(:space)
  end

  # relay ======================================================================

  def relay_to_space(%Event{} = event, target_space, opts) do
    scope = Keyword.fetch!(opts, :scope)

    EventPublication.relay_to_space(
      %{event_id: event.id, relay_note: Keyword.get(opts, :relay_note)},
      scope: %{scope | tenant: target_space}
    )
  end

  def can_relay_event_to_any_space?(%Event{} = event, scope) do
    case list_relay_target_spaces(event, scope) do
      {:ok, relay_target_spaces} -> {:ok, relay_target_spaces != []}
      {:error, error} -> {:error, error}
    end
  end

  # feeds ======================================================================

  defdelegate get_space_feed(user, space_id), to: Feeds
  defdelegate list_aggregate_feed_events(user), to: Feeds

  def list_relay_target_spaces(%Event{} = event, scope) do
    published_space_ids = published_space_ids(event)

    with {:ok, spaces} <-
           Space
           |> Ash.Query.sort(name: :asc)
           |> Ash.read(scope: scope),
         {:ok, spaces} <-
           filter_relay_target_spaces(spaces, event, published_space_ids, scope.actor.id) do
      {:ok, spaces}
    end
  end

  defp published_space_ids(%Event{id: event_id}) do
    from(ep in "event_publications",
      where: ep.event_id == type(^event_id, :binary_id),
      select: ep.target_space_id
    )
    |> Repo.all()
    |> Enum.map(&Ecto.UUID.load!/1)
    |> MapSet.new()
  end

  defp filter_relay_target_spaces(spaces, event, published_space_ids, actor_id) do
    spaces
    |> Enum.reject(&(MapSet.member?(published_space_ids, &1.id) or &1.id == event.space_id))
    |> Enum.reduce_while({:ok, []}, fn space, {:ok, acc} ->
      case Checks.ActorCanRelayEvent.relay_allowed_by_event_policy?(actor_id, event, space.id) do
        {:ok, true} ->
          {:cont, {:ok, [space | acc]}}

        {:ok, false} ->
          {:cont, {:ok, acc}}

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, spaces} ->
        {:ok, Enum.reverse(spaces)}

      {:error, error} ->
        {:error, error}
    end
  end
end
