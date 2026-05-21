defmodule Wik.Events.Feeds do
  require Ash.Query

  alias Wik.Accounts
  alias Wik.Accounts.Space
  alias Wik.Accounts.User
  alias Wik.Events.Event
  alias Wik.Events.EventPublication
  alias Wik.Scope

  def list_aggregate_feed_events(%User{} = user) do
    with {:ok, spaces} <- Accounts.list_spaces(actor: user),
         {:ok, publications} <- load_aggregate_feed_publications(spaces, user) do
      publications =
        Enum.sort_by(
          publications,
          &{&1.event.starts_at, &1.event.inserted_at, &1.inserted_at}
        )

      {:ok, aggregate_feed_entries(publications)}
    end
  end

  def get_space_feed(%User{} = user, space_id) when is_binary(space_id) do
    with {:ok, %Space{} = space} <- Ash.get(Space, space_id, actor: user),
         {:ok, events} <- read_space_feed_events(space, user) do
      {:ok, %{events: events, space: space}}
    end
  end

  defp space_feed_events_query do
    Event
    |> Ash.Query.filter(status != :draft)
    |> Ash.Query.sort(starts_at: :asc, inserted_at: :asc)
  end

  defp read_space_feed_events(%Space{id: space_id}, %User{} = user) do
    space_feed_events_query()
    |> Ash.Query.filter(exists(publications, target_space_id == ^space_id))
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
    |> Ash.Query.load([:space, :published_by, event: [:author, :space]])
  end

  defp load_aggregate_feed_publications(spaces, user) do
    spaces
    |> Enum.reduce_while({:ok, []}, fn space, {:ok, publication_chunks} ->
      space_scope = %Scope{actor: user, tenant: space}

      case Ash.load(space, [event_publications: aggregate_feed_publications_query()],
             scope: space_scope
           ) do
        {:ok, space} ->
          {:cont, {:ok, [space.event_publications | publication_chunks]}}

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
        publications: Enum.sort_by(publications, & &1.space.name)
      }
    end)
  end
end
