defmodule Qblog.Blocks.MarkdownHistory do
  alias Ash.Query
  alias HSDiff
  alias Qblog.Blocks.BlockVersion
  alias Qblog.Blocks.Types.Markdown

  require Ash.Query

  @snapshot_interval 20
  @revision_retry_attempts 3

  def create_initial_version(block, opts) do
    scope = Keyword.fetch!(opts, :scope)

    if block.type == :markdown do
      create_version(block, 1, :snapshot, current_text(block), nil, scope)
    else
      :ok
    end
  end

  def list_versions(block, opts) do
    scope = Keyword.fetch!(opts, :scope)

    BlockVersion
    |> Query.filter(block_id == ^block.id and block_type == :markdown)
    |> Query.sort(revision: :desc)
    |> Ash.read(authorize?: false, scope: scope, load: [:author])
  end

  def update_block(block, params, opts) do
    scope = Keyword.fetch!(opts, :scope)
    current_text = current_text(block)
    updated_text = Markdown.canonical_text_from_params(params)

    if updated_text == current_text do
      {:ok, block}
    else
      update_markdown_block_and_create_version(block, updated_text, opts, scope)
    end
  end

  def version_text(%BlockVersion{storage_kind: :snapshot, snapshot_text: text}, _opts),
    do: {:ok, text || ""}

  def version_text(%BlockVersion{} = version, opts) do
    scope = Keyword.fetch!(opts, :scope)

    with {:ok, snapshot_version} <- get_snapshot_version(version, scope),
         {:ok, versions} <- list_versions_to_replay(version, snapshot_version, scope) do
      text =
        versions
        |> Enum.sort_by(& &1.revision, :asc)
        |> Enum.reduce(snapshot_version.snapshot_text, fn
          %BlockVersion{storage_kind: :snapshot, snapshot_text: snapshot_text}, _text ->
            snapshot_text || ""

          %BlockVersion{storage_kind: :line_diff, diff_data: diff_data}, text ->
            text |> apply_diff(diff_data)
        end)

      {:ok, text}
    end
  end

  defp update_markdown_block_and_create_version(block, updated_text, opts, scope) do
    update_opts =
      opts
      |> Keyword.put(:action, :update)
      |> Keyword.put(:return_notifications?, true)

    case Qblog.Repo.transaction(fn ->
           with {:ok, updated_block, notifications} <-
                  block |> Ash.update(%{data: %{"text" => updated_text}}, update_opts),
                :ok <-
                  create_next_version(block, current_text(block), updated_text, scope) do
             {updated_block, notifications}
           else
             {:error, error} -> Qblog.Repo.rollback(error)
           end
         end) do
      {:ok, {updated_block, notifications}} ->
        Ash.Notifier.notify(notifications)
        {:ok, updated_block}

      {:error, error} ->
        {:error, error}
    end
  end

  defp apply_diff(text, %{"ops" => ops}) do
    text
    |> HSDiff.patch(deserialize_ops(ops))
  end

  defp create_version(block, revision, storage_kind, snapshot_text, diff_data, scope) do
    attrs = %{
      block_id: block.id,
      block_type: :markdown,
      diff_data: diff_data,
      revision: revision,
      snapshot_text: snapshot_text,
      storage_kind: storage_kind
    }

    case Ash.create(
           BlockVersion,
           attrs,
           action: :create,
           authorize?: false,
           return_notifications?: true,
           scope: scope
         ) do
      {:ok, _version, _notifications} -> :ok
      {:ok, _version} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp create_version_for_revision(block, revision, previous_text, updated_text, scope) do
    if snapshot_revision?(revision) do
      create_version(block, revision, :snapshot, updated_text || "", nil, scope)
    else
      diff_data =
        (previous_text || "")
        |> HSDiff.diff(updated_text)
        |> HSDiff.optimize()
        |> serialize_ops()
        |> then(&%{"ops" => &1})

      create_version(block, revision, :line_diff, nil, diff_data, scope)
    end
  end

  defp create_next_version(block, previous_text, updated_text, scope, attempts_left \\ @revision_retry_attempts)

  defp create_next_version(_block, _previous_text, _updated_text, _scope, 0),
    do: {:error, :revision_conflict}

  defp create_next_version(block, previous_text, updated_text, scope, attempts_left) do
    with {:ok, next_revision} <- get_next_revision(block, scope) do
      case create_version_for_revision(block, next_revision, previous_text, updated_text, scope) do
        :ok ->
          :ok

        {:error, error} ->
          if revision_taken?(error) do
            create_next_version(block, previous_text, updated_text, scope, attempts_left - 1)
          else
            {:error, error}
          end
      end
    end
  end

  defp deserialize_ops(ops) do
    Enum.map(ops, fn
      %{"op" => "eq", "count" => count} -> {:eq, count}
      %{"op" => "del", "count" => count} -> {:del, count}
      %{"op" => "ins", "lines" => lines} -> {:ins, lines}
    end)
  end

  defp get_next_revision(block, scope) do
    BlockVersion
    |> Query.filter(block_id == ^block.id and block_type == :markdown)
    |> Query.sort(revision: :desc)
    |> Query.limit(1)
    |> Ash.read(authorize?: false, scope: scope)
    |> case do
      {:ok, versions} ->
        revision =
          case List.first(versions) do
            nil -> 1
            version -> version.revision + 1
          end

        {:ok, revision}

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_snapshot_version(version, scope) do
    BlockVersion
    |> Query.filter(
      block_id == ^version.block_id and
        block_type == :markdown and
        storage_kind == :snapshot and
        revision <= ^version.revision
    )
    |> Query.sort(revision: :desc)
    |> Query.limit(1)
    |> Ash.read(authorize?: false, scope: scope)
    |> case do
      {:ok, versions} ->
        case List.first(versions) do
          nil -> {:error, :snapshot_not_found}
          snapshot_version -> {:ok, snapshot_version}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp list_versions_to_replay(version, snapshot_version, scope) do
    BlockVersion
    |> Query.filter(
      block_id == ^version.block_id and
        block_type == :markdown and
        revision >= ^snapshot_version.revision and
        revision <= ^version.revision
    )
    |> Query.sort(revision: :asc)
    |> Ash.read(authorize?: false, scope: scope)
  end

  defp serialize_ops(ops) do
    Enum.map(ops, fn
      {:eq, count} -> %{"count" => count, "op" => "eq"}
      {:del, count} -> %{"count" => count, "op" => "del"}
      {:ins, lines} -> %{"lines" => lines, "op" => "ins"}
    end)
  end

  defp current_text(block) do
    block.data["text"] || ""
  end

  defp revision_taken?(%Ash.Error.Invalid{errors: errors}) do
    Enum.any?(errors, fn
      %Ash.Error.Changes.InvalidChanges{fields: fields} ->
        Enum.sort(fields) == [:block_id, :revision]

      _ ->
        false
    end)
  end

  defp revision_taken?(_), do: false

  defp snapshot_revision?(1), do: true
  defp snapshot_revision?(revision), do: rem(revision, @snapshot_interval) == 0
end
