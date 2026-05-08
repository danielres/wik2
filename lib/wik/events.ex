defmodule Wik.Events do
  use Ash.Domain,
    otp_app: :wik,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  import Ecto.Query, only: [from: 2]

  alias Wik.Accounts.Group
  alias Wik.Events.Event
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
  end

  # relay ======================================================================

  def relay_to_group(%Event{} = event, target_group, opts) do
    scope = Keyword.fetch!(opts, :scope)

    EventPublication.relay_to_group(
      %{event_id: event.id, relay_note: Keyword.get(opts, :relay_note)},
      scope: %{scope | tenant: target_group}
    )
  end

  def can_relay_event_to_any_group?(%Event{} = event, scope) do
    case list_relay_target_groups(event, scope) do
      {:ok, relay_target_groups} -> {:ok, relay_target_groups != []}
      {:error, error} -> {:error, error}
    end
  end

  # feeds ======================================================================

  defdelegate get_group_feed(user, group_id), to: Feeds
  defdelegate list_aggregate_feed_events(user), to: Feeds

  def list_relay_target_groups(%Event{} = event, scope) do
    published_group_ids = published_group_ids(event)

    with {:ok, groups} <-
           Group
           |> Ash.Query.sort(name: :asc)
           |> Ash.read(scope: scope),
         {:ok, groups} <-
           filter_relay_target_groups(groups, event, published_group_ids, scope.actor.id) do
      {:ok, groups}
    end
  end

  defp published_group_ids(%Event{id: event_id}) do
    from(ep in "event_publications",
      where: ep.event_id == type(^event_id, :binary_id),
      select: ep.target_group_id
    )
    |> Repo.all()
    |> Enum.map(&Ecto.UUID.load!/1)
    |> MapSet.new()
  end

  defp filter_relay_target_groups(groups, event, published_group_ids, actor_id) do
    groups
    |> Enum.reject(&(&1.id in published_group_ids or &1.id == event.group_id))
    |> Enum.reduce_while({:ok, []}, fn group, {:ok, acc} ->
      case Checks.ActorCanRelayEvent.relay_allowed_by_event_policy?(actor_id, event, group.id) do
        {:ok, true} ->
          {:cont, {:ok, acc ++ [group]}}

        {:ok, false} ->
          {:cont, {:ok, acc}}

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
  end
end
