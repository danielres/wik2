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
    groups
    |> Enum.reduce_while({:ok, []}, fn group, {:ok, publication_chunks} ->
      group_scope = %Scope{actor: user, tenant: group}

      case Ash.load(group, [event_publications: aggregate_feed_publications_query()],
             scope: group_scope
           ) do
        {:ok, group} ->
          {:cont, {:ok, [group.event_publications | publication_chunks]}}

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, publication_chunks} ->
        {:ok, publication_chunks |> Enum.reverse() |> List.flatten()}

      {:error, error} ->
        {:error, error}
    end
  end

  defp aggregate_feed_entries(publications) do
    publications
    |> Enum.chunk_by(& &1.event_id)
    |> Enum.map(fn publications ->
      [first | _] = publications

      %{
        event: first.event,
        publications: Enum.sort_by(publications, & &1.group.name)
      }
    end)
  end
end
