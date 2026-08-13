defmodule Wik.Activity.Recorder do
  alias Wik.Activity.Entry
  alias Wik.Repo

  require Ash.Query

  @collapse_window_seconds 15 * 60

  def record(attrs, opts \\ []) when is_map(attrs) do
    occurred_at = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)
    collapse_mode = Map.get(attrs, :collapse_mode, :matching)
    collapsible? = Map.get(attrs, :collapsible?, false)

    attrs =
      attrs
      |> Map.delete(:collapse_mode)
      |> Map.delete(:collapsible?)
      |> Map.put(:occurred_at, occurred_at)

    if collapsible? do
      record_collapsible(attrs, occurred_at, collapse_mode)
    else
      create_entry(attrs)
    end
  end

  defp record_collapsible(
         %{collapse_key: collapse_key, space_id: space_id} = attrs,
         recorded_at,
         collapse_mode
       )
       when is_binary(collapse_key) do
    lock_id = collapse_lock_id(space_id, collapse_key, collapse_mode)

    case Repo.transaction(fn ->
           Ecto.Adapters.SQL.query!(Repo, "SELECT pg_advisory_xact_lock($1)", [lock_id])

           cutoff = DateTime.add(recorded_at, -@collapse_window_seconds, :second)

           existing_entry = find_collapsible_entry(attrs, cutoff, recorded_at, collapse_mode)

           case existing_entry do
             nil -> create_entry_in_transaction(attrs)
             entry -> collapse_entry_in_transaction(entry, attrs, collapse_mode)
           end
         end) do
      {:ok, {entry, notifications}} ->
        Ash.Notifier.notify(notifications)
        {:ok, entry}

      {:error, error} ->
        {:error, error}
    end
  end

  defp record_collapsible(attrs, _occurred_at, _collapse_mode), do: create_entry(attrs)

  defp find_collapsible_entry(attrs, cutoff, recorded_at, :consecutive_targets) do
    latest_entry =
      Entry
      |> Ash.Query.filter(
        space_id == ^attrs.space_id and occurred_at >= type(^cutoff, :utc_datetime_usec) and
          occurred_at <= type(^recorded_at, :utc_datetime_usec)
      )
      |> Ash.Query.sort(occurred_at: :desc, id: :desc)
      |> Ash.Query.limit(1)
      |> Ash.read_one!(authorize?: false, tenant: attrs.space_id)

    if latest_entry && latest_entry.collapse_key == attrs.collapse_key,
      do: latest_entry,
      else: nil
  end

  defp find_collapsible_entry(attrs, cutoff, recorded_at, _collapse_mode) do
    Entry
    |> Ash.Query.filter(
      collapse_key == ^attrs.collapse_key and space_id == ^attrs.space_id and
        occurred_at >= type(^cutoff, :utc_datetime_usec) and
        occurred_at <= type(^recorded_at, :utc_datetime_usec)
    )
    |> Ash.Query.sort(occurred_at: :desc, id: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false, tenant: attrs.space_id)
  end

  defp collapse_lock_id(space_id, _collapse_key, :consecutive_targets),
    do: :erlang.phash2("#{space_id}:consecutive_targets", 2_147_483_647)

  defp collapse_lock_id(space_id, collapse_key, _collapse_mode),
    do: :erlang.phash2("#{space_id}:#{collapse_key}", 2_147_483_647)

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

  defp collapse_entry_in_transaction(entry, attrs, collapse_mode) do
    collapse_attrs = %{
      actor_label: attrs.actor_label,
      actor_membership_id: attrs.actor_membership_id,
      actor_username: attrs.actor_username,
      kind: attrs.kind,
      metadata: collapse_metadata(entry, attrs, collapse_mode),
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

  defp collapse_metadata(entry, attrs, :consecutive_targets) do
    targets =
      entry.metadata
      |> metadata_value(:targets, [])
      |> merge_targets(metadata_value(attrs.metadata, :targets, []))

    attrs.metadata
    |> Map.delete(:targets)
    |> Map.delete("targets")
    |> Map.put(:targets, targets)
  end

  defp collapse_metadata(_entry, attrs, _collapse_mode), do: attrs.metadata

  defp merge_targets(existing_targets, incoming_targets) do
    Enum.reduce(incoming_targets, existing_targets, fn incoming_target, targets ->
      incoming_id = metadata_value(incoming_target, :id)

      if Enum.any?(targets, &(metadata_value(&1, :id) == incoming_id)) do
        Enum.map(targets, fn target ->
          if metadata_value(target, :id) == incoming_id, do: incoming_target, else: target
        end)
      else
        targets ++ [incoming_target]
      end
    end)
  end

  defp metadata_value(metadata, key, default \\ nil) do
    Map.get(metadata, key) || Map.get(metadata, Atom.to_string(key)) || default
  end
end
