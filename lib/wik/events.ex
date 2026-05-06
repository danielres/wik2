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
  alias Wik.Events.EventPublication.Checks.ActorCanRelayEvent
  alias Wik.Repo

  admin do
    show? true
  end

  resources do
    resource Event
    resource EventPublication
  end

  def create_event(attrs, opts) do
    scope = Keyword.fetch!(opts, :scope)
    load = Keyword.get(opts, :load, [])
    opts = Keyword.put_new(opts, :return_notifications?, true)

    case Event.create(attrs, opts) do
      {:ok, event, notifications} ->
        Ash.Notifier.notify(notifications)
        Ash.load(event, load, scope: scope)

      {:ok, event} ->
        Ash.load(event, load, scope: scope)

      {:error, error} ->
        {:error, error}
    end
  end

  def relay_event_to_group(%Event{} = event, target_group, opts) do
    scope = Keyword.fetch!(opts, :scope)
    relay_note = Keyword.get(opts, :relay_note)
    relay_scope = %{scope | tenant: target_group}

    attrs =
      if is_nil(relay_note),
        do: %{event_id: event.id},
        else: %{event_id: event.id, relay_note: relay_note}

    EventPublication.relay_to_group(attrs, scope: relay_scope)
  end

  def can_relay_event_to_any_group?(%Event{} = event, scope) do
    case list_relay_target_groups(event, scope) do
      {:ok, relay_target_groups} -> {:ok, relay_target_groups != []}
      {:error, error} -> {:error, error}
    end
  end

  def list_relay_target_groups(%Event{} = event, scope) do
    published_group_ids = published_group_ids(event)

    Group
    |> Ash.Query.sort(name: :asc)
    |> Ash.read(domain: Wik.Accounts, scope: scope)
    |> case do
      {:ok, groups} ->
        groups
        |> Enum.reject(&(&1.id in published_group_ids))
        |> Enum.reject(&(&1.id == event.group_id))
        |> Enum.reduce_while({:ok, []}, fn group, {:ok, acc} ->
          case ActorCanRelayEvent.relay_allowed_by_event_policy?(
                 scope.actor.id,
                 event,
                 group.id
               ) do
            {:ok, true} ->
              {:cont, {:ok, [group | acc]}}

            {:ok, false} ->
              {:cont, {:ok, acc}}

            {:error, error} ->
              {:halt, {:error, error}}
          end
        end)
        |> case do
          {:ok, groups} -> {:ok, Enum.reverse(groups)}
          {:error, error} -> {:error, error}
        end

      {:error, error} ->
        {:error, error}
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
end
