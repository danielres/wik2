defmodule Wik.Events.Feeds do
  require Ash.Query

  alias Wik.Accounts
  alias Wik.Accounts.Space
  alias Wik.Accounts.User
  alias Wik.Events.EventParticipation
  alias Wik.Events.EventPublication
  alias Wik.Events.ExternalEvent
  alias Wik.Scope

  def list_aggregate_feed_events(%User{} = user) do
    with {:ok, spaces} <- Accounts.list_spaces(actor: user),
         {:ok, publications} <- load_aggregate_feed_publications(spaces, user),
         {:ok, external_entries} <- load_aggregate_feed_external_entries(spaces, user) do
      entries =
        publications
        |> aggregate_feed_entries()
        |> Kernel.++(external_entries)
        |> Enum.sort_by(&feed_entry_sort_key/1)

      {:ok, entries}
    end
  end

  def get_space_feed(%User{} = user, space_id) when is_binary(space_id) do
    with {:ok, %Space{} = space} <- Ash.get(Space, space_id, actor: user),
         {:ok, events} <- read_space_feed_events(space, user) do
      {:ok, %{events: events, space: space}}
    end
  end

  defp read_space_feed_events(%Space{} = space, %User{} = user) do
    with {:ok, publications} <- load_space_feed_publications(space, user) do
      {:ok, Enum.map(publications, & &1.event)}
    end
  end

  defp aggregate_feed_publications_query do
    EventPublication
    |> Ash.Query.filter(event.status != :draft)
    |> Ash.Query.sort([
      {"event.starts_at", :asc},
      {"event.inserted_at", :asc},
      {:inserted_at, :asc}
    ])
    |> Ash.Query.load([
      :space,
      :published_by,
      participations: [membership: [:avatar_url, user: [:external_identities]]],
      event: [:author, :space]
    ])
  end

  defp aggregate_feed_external_participations_query do
    EventParticipation
    |> Ash.Query.filter(not is_nil(external_event_id) and external_event.status != :draft)
    |> Ash.Query.sort([
      {"external_event.starts_at", :asc},
      {:inserted_at, :asc}
    ])
    |> Ash.Query.load(
      membership: [:avatar_url, user: [:external_identities]],
      external_event: [:space]
    )
  end

  defp space_feed_publications_query do
    EventPublication
    |> Ash.Query.filter(event.status != :draft)
    |> Ash.Query.sort([
      {"event.starts_at", :asc},
      {"event.inserted_at", :asc},
      {:inserted_at, :asc}
    ])
    |> Ash.Query.load(event: [:author, :space])
  end

  defp load_space_feed_publications(%Space{} = space, user) do
    space_feed_publications_query()
    |> Ash.read(scope: %Scope{actor: user, tenant: space})
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

  defp load_aggregate_feed_external_entries(spaces, user) do
    spaces
    |> Enum.reduce_while({:ok, []}, fn space, {:ok, entry_chunks} ->
      space_scope = %Scope{actor: user, tenant: space}

      case Ash.read(aggregate_feed_external_participations_query(), scope: space_scope) do
        {:ok, participations} ->
          {:cont, {:ok, [external_feed_entries(participations) | entry_chunks]}}

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, entry_chunks} ->
        {:ok, entry_chunks |> Enum.reverse() |> List.flatten()}

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
        participations: Enum.flat_map(publications, & &1.participations),
        publications: Enum.sort_by(publications, & &1.space.name)
      }
    end)
  end

  defp external_feed_entries(participations) do
    participations
    |> Enum.group_by(& &1.external_event_id)
    |> Enum.map(fn {_external_event_id, participations} ->
      [first | _] = participations

      %{
        external_event: first.external_event,
        participations: participations,
        space: first.external_event.space
      }
    end)
  end

  defp feed_entry_sort_key(%{event: event}) do
    {event.starts_at, event.inserted_at, event.id}
  end

  defp feed_entry_sort_key(%{external_event: %ExternalEvent{} = event}) do
    {event.starts_at, event.inserted_at, event.id}
  end
end
