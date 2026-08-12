defmodule Wik.Activity.Recorder do
  alias Wik.Activity.Entry
  alias Wik.Repo

  require Ash.Query

  @collapse_window_seconds 15 * 60

  def record(attrs, opts \\ []) when is_map(attrs) do
    occurred_at = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)
    collapsible? = Map.get(attrs, :collapsible?, false)

    attrs =
      attrs
      |> Map.delete(:collapsible?)
      |> Map.put(:occurred_at, occurred_at)

    if collapsible? do
      record_collapsible(attrs, occurred_at)
    else
      create_entry(attrs)
    end
  end

  defp record_collapsible(%{collapse_key: collapse_key, space_id: space_id} = attrs, occurred_at)
       when is_binary(collapse_key) do
    lock_id = :erlang.phash2("#{space_id}:#{collapse_key}", 2_147_483_647)

    case Repo.transaction(fn ->
           Ecto.Adapters.SQL.query!(Repo, "SELECT pg_advisory_xact_lock($1)", [lock_id])

           cutoff = DateTime.add(occurred_at, -@collapse_window_seconds, :second)

           existing_entry =
             Entry
             |> Ash.Query.filter(
               collapse_key == ^collapse_key and space_id == ^space_id and
                 occurred_at >= ^cutoff
             )
             |> Ash.Query.sort(occurred_at: :desc)
             |> Ash.Query.limit(1)
             |> Ash.read_one!(authorize?: false, tenant: space_id)

           case existing_entry do
             nil -> create_entry_in_transaction(attrs)
             entry -> collapse_entry_in_transaction(entry, attrs)
           end
         end) do
      {:ok, {entry, notifications}} ->
        Ash.Notifier.notify(notifications)
        {:ok, entry}

      {:error, error} ->
        {:error, error}
    end
  end

  defp record_collapsible(attrs, _occurred_at), do: create_entry(attrs)

  defp create_entry(attrs) do
    Ash.create(Entry, attrs,
      action: :record,
      authorize?: false,
      tenant: attrs.space_id
    )
  end

  defp create_entry_in_transaction(attrs) do
    case Ash.create(Entry, attrs,
           action: :record,
           authorize?: false,
           return_notifications?: true,
           tenant: attrs.space_id
         ) do
      {:ok, entry, notifications} -> {entry, notifications}
      {:error, error} -> Repo.rollback(error)
    end
  end

  defp collapse_entry_in_transaction(entry, attrs) do
    collapse_attrs = %{
      actor_label: attrs.actor_label,
      actor_membership_id: attrs.actor_membership_id,
      actor_username: attrs.actor_username,
      kind: attrs.kind,
      metadata: attrs.metadata,
      occurred_at: attrs.occurred_at,
      occurrence_count: entry.occurrence_count + 1,
      subject_label: attrs.subject_label,
      subject_path: attrs.subject_path
    }

    case Ash.update(entry, collapse_attrs,
           action: :collapse,
           authorize?: false,
           return_notifications?: true,
           tenant: attrs.space_id
         ) do
      {:ok, entry, notifications} -> {entry, notifications}
      {:error, error} -> Repo.rollback(error)
    end
  end
end
