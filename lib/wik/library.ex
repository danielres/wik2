defmodule Wik.Library do
  use Ash.Domain,
    otp_app: :wik,
    extensions: [AshAdmin.Domain, AshPhoenix]

  alias Ash.Query
  alias Wik.Blocks
  alias Wik.Library.BlockReference
  alias Wik.Library.Entry
  alias Wik.Library.EntryType
  alias Wik.Library.Field
  alias Wik.Library.Settings
  alias Wik.Library.TopicExclusion
  alias Wik.Library.TopicRule
  alias Wik.Tags.Tagging
  alias WikWeb.LibraryLive.Schema

  require Ash.Query

  admin do
    show? true
  end

  resources do
    resource BlockReference
    resource Entry
    resource EntryType
    resource Field
    resource Settings
    resource TopicExclusion
    resource TopicRule
  end

  def list_entry_types(opts) do
    EntryType
    |> Query.sort(name: :asc)
    |> Ash.read(opts)
  end

  def get_entry_type(id, opts) do
    EntryType
    |> Query.filter(id == ^id)
    |> Query.load(:fields)
    |> Ash.read_one(opts)
  end

  def get_entry_type_by_slug(slug, opts) do
    EntryType
    |> Query.filter(slug == ^slug)
    |> Query.load(:fields)
    |> Ash.read_one(opts)
  end

  def list_entries(opts) do
    Entry
    |> Query.sort(inserted_at: :desc)
    |> Query.load(entry_load())
    |> Ash.read(opts)
  end

  def create_entry(type, params, metadata, opts) do
    with {:ok, values} <- Schema.entry_values(type.fields, params) do
      Ash.create(
        Entry,
        %{external_media_metadata: metadata, type_id: type.id, values: values},
        Keyword.put(opts, :action, :create)
      )
    end
  end

  def update_entry(entry, params, metadata, opts) do
    with {:ok, values} <- Schema.entry_values(entry.type.fields, params) do
      Ash.update(
        entry,
        %{external_media_metadata: metadata, values: values},
        Keyword.put(opts, :action, :update)
      )
    end
  end

  def destroy_entry(entry, opts) do
    Ash.destroy(entry, Keyword.put(opts, :action, :destroy))
  end

  def list_entries_for_type(type_id, opts) do
    Entry
    |> Query.filter(type_id == ^type_id)
    |> Query.sort(inserted_at: :desc)
    |> Query.load(entry_load())
    |> Ash.read(opts)
  end

  def get_entry(id, opts) do
    Entry
    |> Query.filter(id == ^id)
    |> Query.load(entry_load())
    |> Ash.read_one(opts)
  end

  def get_block_reference(block_id, opts) do
    BlockReference
    |> Query.filter(block_id == ^block_id)
    |> Query.load(entry: [:creator, type: :fields])
    |> Ash.read_one(opts)
  end

  def entry_reference_count(entry_id, opts) do
    BlockReference
    |> Query.filter(entry_id == ^entry_id)
    |> Ash.count(opts)
  end

  def create_entry_block_on_page(%Entry{} = entry, page, opts) do
    scope = Keyword.fetch!(opts, :scope)
    position = Keyword.get(opts, :position, :bottom)

    case Blocks.create_space_owned_block_on_page(
           scope.tenant,
           page,
           %{type: :library_entry},
           position: position,
           scope: scope
         ) do
      {:ok, block} ->
        case create_block_reference(block, entry, scope) do
          {:ok, _reference} ->
            {:ok, block}

          {:error, error} ->
            cleanup_unreferenced_block(block, scope)
            {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  def entry_load, do: [:creator, type: :fields]

  defp create_block_reference(block, entry, scope) do
    with true <- block.type == :library_entry,
         true <- entry.space_id == block.owner_space_id do
      Ash.create(
        BlockReference,
        %{block_id: block.id, entry_id: entry.id},
        action: :create,
        scope: scope
      )
    else
      false when block.type != :library_entry -> {:error, :invalid_block_type}
      false -> {:error, :entry_space_mismatch}
    end
  end

  defp cleanup_unreferenced_block(block, scope) do
    with {:ok, %{placements: placements}} <- Ash.load(block, :placements, scope: scope) do
      Enum.each(placements, &Blocks.destroy_placed_block(&1, scope: scope))
      Blocks.destroy_orphan_space_owned_block(scope.tenant, block.id, scope: scope)
    end

    :ok
  end

  def snapshot(scope) do
    :ok = Wik.Library.Provisioning.ensure_default_types(scope)

    {:ok, types} =
      EntryType
      |> Query.sort(name: :asc)
      |> Query.load(:fields)
      |> Ash.read(scope: scope)

    {:ok, entries} = list_entries(scope: scope)
    {:ok, rules} = Ash.read(TopicRule, scope: scope)
    {:ok, exclusions} = Ash.read(TopicExclusion, scope: scope)
    settings = load_or_create_settings(scope)

    {:ok, taggings} =
      Tagging
      |> Query.filter(taggable_type == "library_entry")
      |> Query.load(:tag)
      |> Ash.read(scope: scope)

    %{
      automatic_exclusions: MapSet.new(exclusions, &{&1.entry_id, &1.tag_id}),
      automatic_topic_matching?: settings.automatic_topic_matching,
      entries: Map.new(entries, &{&1.id, &1}),
      scope: scope,
      topic_contributions:
        Map.new(taggings, fn tagging ->
          contribution = %{
            entry_id: tagging.taggable_id,
            membership_id: tagging.tagged_by_membership_id,
            relevancy: Map.get(tagging.dimensions, "relevancy"),
            tagging: tagging,
            topic_id: tagging.tag_id
          }

          {{contribution.entry_id, contribution.membership_id, contribution.topic_id},
           contribution}
        end),
      topic_rules:
        Map.new(rules, &{&1.tag_id, %{aliases: &1.aliases, enabled?: &1.enabled, record: &1}}),
      types: types
    }
  end

  def page_snapshot(scope) do
    :ok = Wik.Library.Provisioning.ensure_default_types(scope)

    {:ok, types} =
      EntryType
      |> Query.sort(name: :asc)
      |> Query.load(:fields)
      |> Ash.read(scope: scope)

    {:ok, entries} = list_entries(scope: scope)

    %{
      automatic_exclusions: MapSet.new(),
      automatic_topic_matching?: false,
      entries: Map.new(entries, &{&1.id, &1}),
      scope: scope,
      topic_contributions: %{},
      topic_rules: %{},
      types: types
    }
  end

  defp load_or_create_settings(scope) do
    case Ash.read_one(Settings, scope: scope) do
      {:ok, nil} ->
        create_settings(scope)

      {:ok, settings} ->
        settings

      {:error, error} ->
        raise error
    end
  end

  defp create_settings(scope) do
    case Ash.create(Settings, %{},
           action: :create,
           actor: scope.actor,
           authorize?: false,
           tenant: scope.tenant
         ) do
      {:ok, settings} ->
        settings

      {:error, error} ->
        if settings_already_exist?(error) do
          load_existing_settings!(scope, error)
        else
          raise error
        end
    end
  end

  defp load_existing_settings!(scope, error) do
    case Ash.read_one(Settings, scope: scope) do
      {:ok, %Settings{} = settings} -> settings
      {:ok, nil} -> raise error
      {:error, read_error} -> raise read_error
    end
  end

  defp settings_already_exist?(%Ash.Error.Invalid{errors: errors}) do
    Enum.any?(errors, fn
      %Ash.Error.Changes.InvalidChanges{fields: fields} ->
        Enum.any?(fields, &(&1 in [:space, :space_id]))

      _ ->
        false
    end)
  end

  defp settings_already_exist?(_), do: false
end
