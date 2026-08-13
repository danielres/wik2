defmodule Wik.Activity.Entry.Calculations.EventStartsAt do
  use Ash.Resource.Calculation

  alias Wik.Events.Event
  alias Wik.Events.ExternalEvent

  require Ash.Query

  @impl true
  def calculate([], _opts, _context), do: {:ok, []}

  def calculate(entries, _opts, context) do
    with {:ok, internal_events} <- load_events(entries, Event, :internal, context),
         {:ok, external_events} <- load_events(entries, ExternalEvent, :external, context) do
      starts_at_by_reference = Map.merge(internal_events, external_events)

      {:ok,
       Enum.map(entries, fn entry ->
         Map.get(starts_at_by_reference, {event_source(entry), entry.subject_id})
       end)}
    end
  end

  defp load_events(entries, resource, source, context) do
    if context.tenant do
      load_events_for_tenant(entries, resource, source, context, context.tenant)
    else
      entries
      |> Enum.group_by(& &1.space_id)
      |> Enum.reduce_while({:ok, %{}}, fn {space_id, space_entries}, {:ok, events} ->
        case load_events_for_tenant(space_entries, resource, source, context, space_id) do
          {:ok, space_events} -> {:cont, {:ok, Map.merge(events, space_events)}}
          {:error, error} -> {:halt, {:error, error}}
        end
      end)
    end
  end

  defp load_events_for_tenant(entries, resource, source, context, tenant) do
    event_ids =
      entries
      |> Enum.filter(&(&1.subject_type == :event and event_source(&1) == source))
      |> Enum.map(& &1.subject_id)
      |> Enum.uniq()

    if event_ids == [] do
      {:ok, %{}}
    else
      resource
      |> Ash.Query.filter(id in ^event_ids)
      |> Ash.Query.select([:id, :starts_at])
      |> Ash.read(
        actor: context.actor,
        authorize?: context.authorize?,
        tenant: tenant
      )
      |> case do
        {:ok, events} -> {:ok, Map.new(events, &{{source, &1.id}, &1.starts_at})}
        {:error, error} -> {:error, error}
      end
    end
  end

  defp event_source(%{metadata: metadata}) do
    case Map.get(metadata, :source_type) || Map.get(metadata, "source_type") do
      source when source in [:external, "external"] -> :external
      _source -> :internal
    end
  end
end
