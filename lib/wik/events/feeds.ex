defmodule Wik.Events.Feeds do
  require Ash.Query

  alias Wik.Accounts
  alias Wik.Accounts.Group
  alias Wik.Accounts.User
  alias Wik.Events.Event
  alias Wik.Events.EventPublication
  alias Wik.Scope

  def list_aggregate_feed_events(%User{} = user) do
    with {:ok, groups} <- Accounts.list_groups(actor: user),
         {:ok, publications} <- load_aggregate_feed_publications(groups, user) do
      publications =
        Enum.sort_by(
          publications,
          &{&1.event.starts_at, &1.event.inserted_at, &1.inserted_at}
        )

      {:ok, aggregate_feed_entries(publications)}
    end
  end

  def get_group_feed(%User{} = user, group_id) when is_binary(group_id) do
    with {:ok, %Group{} = group} <- Ash.get(Group, group_id, actor: user),
         {:ok, events} <- read_group_feed_events(group, user) do
      {:ok, %{events: events, group: group}}
    end
  end

  defp group_feed_events_query do
    Event
    |> Ash.Query.filter(status != :draft)
    |> Ash.Query.sort(starts_at: :asc, inserted_at: :asc)
  end

  defp read_group_feed_events(%Group{id: group_id}, %User{} = user) do
    group_feed_events_query()
    |> Ash.Query.filter(exists(publications, target_group_id == ^group_id))
    |> Ash.read(actor: user)
  end

  defp aggregate_feed_publications_query do
    EventPublication
    |> Ash.Query.filter(event.status != :draft)
    |> Ash.Query.sort([
      {"event.starts_at", :asc},
      {"event.inserted_at", :asc},
      {:inserted_at, :asc}
    ])
    |> Ash.Query.load([:group, :published_by, event: [:author, :group]])
  end

  defp load_aggregate_feed_publications(groups, user) do
    Enum.reduce_while(groups, {:ok, []}, fn group, {:ok, publications} ->
      group_scope = %Scope{actor: user, tenant: group}

      case Ash.load(group, [event_publications: aggregate_feed_publications_query()],
             scope: group_scope
           ) do
        {:ok, group} ->
          {:cont, {:ok, publications ++ group.event_publications}}

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
  end

  defp aggregate_feed_entries(publications) do
    publications
    |> Enum.group_by(& &1.event_id)
    |> Enum.map(fn {_event_id, publications} ->
      [first | _] = publications

      %{
        event: first.event,
        publications: Enum.sort_by(publications, & &1.group.name)
      }
    end)
  end
end
