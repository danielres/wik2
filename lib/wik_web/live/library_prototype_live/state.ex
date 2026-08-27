defmodule WikWeb.LibraryPrototypeLive.State do
  @moduledoc false

  alias WikWeb.LibraryPrototypeLive.Schema

  def new do
    collections = seeded_collections()

    %{
      collections: collections,
      entries: seeded_entries(collections) |> Map.new(&{&1.id, &1})
    }
  end

  def navigation(state) do
    Enum.map(state.collections, fn collection ->
      Map.put(collection, :entry_count, state |> entries_for(collection.id) |> length())
    end)
  end

  def default_collection(state), do: List.first(state.collections)
  def find_collection(state, slug), do: Enum.find(state.collections, &(&1.slug == slug))
  def find_entry(state, id), do: Map.get(state.entries, id)

  def entries_for(state, collection_id) do
    state.entries
    |> Map.values()
    |> Enum.filter(&(&1.collection_id == collection_id))
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
  end

  def create_collection(state, draft) do
    with {:ok, attrs} <- Schema.collection_attrs(stringify_keys(draft)),
         {:ok, entry_creation_permission} <-
           validate_entry_creation_permission(Map.get(draft, :entry_creation_permission)) do
      collection = %{
        description: attrs.description,
        entry_creation_permission: entry_creation_permission,
        fields: draft.fields,
        id: unique_id("collection"),
        name: attrs.name,
        slug: unique_slug(state, attrs.name)
      }

      {:ok, %{state | collections: state.collections ++ [collection]}, collection}
    end
  end

  def update_collection(state, collection_id, params) do
    with {:ok, attrs} <- Schema.collection_attrs(params),
         %{} = collection <- find_collection_by_id(state, collection_id) do
      collection = Map.merge(collection, attrs)
      {:ok, put_collection(state, collection), collection}
    else
      nil -> {:error, "That collection is no longer available."}
      {:error, message} -> {:error, message}
    end
  end

  def update_entry_creation_permission(state, collection_id, permission)
      when permission in ["members", "admins"] do
    with %{} = collection <- find_collection_by_id(state, collection_id) do
      permission = if permission == "members", do: :members, else: :admins
      collection = %{collection | entry_creation_permission: permission}

      {:ok, put_collection(state, collection), collection}
    else
      nil -> {:error, "That collection is no longer available."}
    end
  end

  def update_entry_creation_permission(_state, _collection_id, _permission) do
    {:error, "Choose who can add entries."}
  end

  def delete_collection(state, collection_id) do
    collections = Enum.reject(state.collections, &(&1.id == collection_id))

    entries =
      state.entries
      |> Map.values()
      |> Enum.reject(&(&1.collection_id == collection_id))
      |> Map.new(&{&1.id, &1})

    %{state | collections: collections, entries: entries}
  end

  def add_field(state, collection_id, params) do
    with %{} = collection <- find_collection_by_id(state, collection_id),
         {:ok, field} <- Schema.field_attrs(params, collection.fields) do
      collection = %{collection | fields: collection.fields ++ [field]}
      {:ok, put_collection(state, collection), collection, field}
    else
      nil -> {:error, "That collection is no longer available."}
      {:error, message} -> {:error, message}
    end
  end

  def update_field(state, collection_id, field_id, params) do
    with %{} = collection <- find_collection_by_id(state, collection_id),
         %{} = existing_field <- Enum.find(collection.fields, &(&1.id == field_id)),
         {:ok, field} <- Schema.field_attrs(params, collection.fields, existing_field),
         :ok <- validate_field_change(state, collection, existing_field, field) do
      fields = Enum.map(collection.fields, &if(&1.id == field.id, do: field, else: &1))
      collection = %{collection | fields: fields}
      {:ok, put_collection(state, collection), collection, field}
    else
      nil -> {:error, "That field is no longer available."}
      {:error, message} -> {:error, message}
    end
  end

  def delete_field(state, collection_id, field_id) do
    with %{} = collection <- find_collection_by_id(state, collection_id),
         %{} = field <- Enum.find(collection.fields, &(&1.id == field_id)),
         false <- field.type == :title do
      fields = Enum.reject(collection.fields, &(&1.id == field_id))
      collection = %{collection | fields: fields}

      entries =
        state.entries
        |> Map.new(fn {entry_id, entry} ->
          if entry.collection_id == collection_id do
            {entry_id, %{entry | values: Map.delete(entry.values, field.key)}}
          else
            {entry_id, entry}
          end
        end)

      {:ok, %{put_collection(state, collection) | entries: entries}, collection}
    else
      nil -> {:error, "That field is no longer available."}
      true -> {:error, "The title field cannot be deleted."}
    end
  end

  def move_field(state, collection_id, field_id, direction) when direction in [:up, :down] do
    with %{} = collection <- find_collection_by_id(state, collection_id),
         index when is_integer(index) <- Enum.find_index(collection.fields, &(&1.id == field_id)),
         false <- index == 0 do
      destination = if direction == :up, do: index - 1, else: index + 1

      fields =
        if destination in 1..(length(collection.fields) - 1) do
          field = Enum.at(collection.fields, index)

          collection.fields
          |> List.delete_at(index)
          |> List.insert_at(destination, field)
        else
          collection.fields
        end

      collection = %{collection | fields: fields}
      {:ok, put_collection(state, collection), collection}
    else
      nil -> {:error, "That field is no longer available."}
      true -> {:error, "The title field always stays first."}
    end
  end

  def field_usage_count(state, collection_id, field) do
    state
    |> entries_for(collection_id)
    |> Enum.count(fn entry -> not Schema.blank_value?(Schema.field_value(entry, field)) end)
  end

  def create_entry(state, collection, creator_id, admin?, params) do
    with true <- can_create_entry?(collection, admin?),
         {:ok, values} <- Schema.entry_values(collection.fields, params) do
      entry = %{
        collection_id: collection.id,
        creator_id: creator_id,
        id: unique_id("entry"),
        inserted_at: DateTime.utc_now(),
        values: values
      }

      {:ok, %{state | entries: Map.put(state.entries, entry.id, entry)}, entry}
    else
      false -> {:error, :forbidden}
      {:error, errors} -> {:error, errors}
    end
  end

  def update_entry(state, collection, entry_id, actor_id, admin?, params) do
    with %{} = entry <- find_entry(state, entry_id),
         true <- entry.collection_id == collection.id,
         true <- can_manage_entry?(entry, actor_id, admin?),
         {:ok, values} <- Schema.entry_values(collection.fields, params) do
      entry = %{entry | values: values}
      {:ok, %{state | entries: Map.put(state.entries, entry.id, entry)}, entry}
    else
      nil -> {:error, :not_found}
      false -> {:error, :forbidden}
      {:error, errors} -> {:error, errors}
    end
  end

  def delete_entry(state, collection_id, entry_id, actor_id, admin?) do
    with %{} = entry <- find_entry(state, entry_id),
         true <- entry.collection_id == collection_id,
         true <- can_manage_entry?(entry, actor_id, admin?) do
      {:ok, %{state | entries: Map.delete(state.entries, entry_id)}, entry}
    else
      nil -> {:error, :not_found}
      false -> {:error, :forbidden}
    end
  end

  def can_manage_entry?(entry, actor_id, admin?) do
    admin? or (is_binary(actor_id) and entry.creator_id == actor_id)
  end

  def can_create_entry?(%{entry_creation_permission: :members}, _admin?), do: true
  def can_create_entry?(%{entry_creation_permission: :admins}, admin?), do: admin?

  defp validate_field_change(state, collection, existing_field, field) do
    usage_count = field_usage_count(state, collection.id, existing_field)

    cond do
      existing_field.type == :title and field.type != :title ->
        {:error, "The title field type cannot be changed."}

      existing_field.type == :title and not field.required? ->
        {:error, "The title field is always required."}

      existing_field.type != field.type and usage_count > 0 ->
        {:error, "Clear this field from every entry before changing its type."}

      not existing_field.required? and field.required? and
          entries_missing_field?(state, collection.id, existing_field) ->
        {:error, "Fill this field in every entry before making it required."}

      existing_field.type == :select and field.type == :select and
          used_select_options_removed?(state, collection.id, existing_field, field) ->
        {:error, "A select option still used by an entry cannot be removed."}

      true ->
        :ok
    end
  end

  defp entries_missing_field?(state, collection_id, field) do
    state
    |> entries_for(collection_id)
    |> Enum.any?(fn entry -> Schema.blank_value?(Schema.field_value(entry, field)) end)
  end

  defp used_select_options_removed?(state, collection_id, existing_field, field) do
    removed_options = existing_field.options -- field.options

    state
    |> entries_for(collection_id)
    |> Enum.any?(fn entry -> Schema.field_value(entry, existing_field) in removed_options end)
  end

  defp find_collection_by_id(state, id), do: Enum.find(state.collections, &(&1.id == id))

  defp put_collection(state, collection) do
    collections =
      Enum.map(state.collections, &if(&1.id == collection.id, do: collection, else: &1))

    %{state | collections: collections}
  end

  defp unique_slug(state, name) do
    base =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/u, "-")
      |> String.trim("-")
      |> case do
        "" -> "collection"
        slug -> slug
      end

    used_slugs = MapSet.new(state.collections, & &1.slug)

    Stream.iterate(1, &(&1 + 1))
    |> Enum.find_value(fn
      1 -> if not MapSet.member?(used_slugs, base), do: base
      suffix -> if not MapSet.member?(used_slugs, "#{base}-#{suffix}"), do: "#{base}-#{suffix}"
    end)
  end

  defp stringify_keys(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  defp validate_entry_creation_permission("members"), do: {:ok, :members}
  defp validate_entry_creation_permission("admins"), do: {:ok, :admins}

  defp validate_entry_creation_permission(_permission),
    do: {:error, "Choose who can add entries."}

  defp unique_id(prefix) do
    "#{prefix}-#{System.unique_integer([:monotonic, :positive])}"
  end

  defp seeded_collections do
    Schema.built_in_templates()
    |> Enum.reject(&(&1.id == "custom"))
    |> Enum.map(fn template ->
      draft = Schema.instantiate_template(template)

      %{
        description: draft.description,
        entry_creation_permission: :members,
        fields: draft.fields,
        id: "collection-#{template.id}",
        name: template.name,
        slug: template.id
      }
    end)
  end

  defp seeded_entries(collections) do
    now = DateTime.utc_now()

    [
      seeded_entry(collections, "places", "entry-place", now, %{
        "location" => "Spreeacker, Wilhelmine-Gemberg-Weg 12, Berlin",
        "name" => "Spreeacker",
        "notes" => "Community garden and open-air dance location.",
        "phone" => "+49 30 123456",
        "website" => "https://example.org/spreeacker"
      }),
      seeded_entry(collections, "contacts", "entry-contact", DateTime.add(now, -60, :second), %{
        "email" => "hello@example.org",
        "name" => "Dr. Ada Rivera",
        "notes" => "English and German consultations.",
        "organization" => "Community Health Practice",
        "phone" => "+49 30 654321",
        "role" => "General practitioner",
        "website" => "https://example.org/health"
      }),
      seeded_entry(collections, "videos", "entry-video", DateTime.add(now, -120, :second), %{
        "creator" => "Local-first community",
        "media" => "https://www.youtube.com/watch?v=BvlGs25tCxI",
        "notes" =>
          "A gentle introduction to tools that keep communities in control of their data.",
        "title" => "Local-first software: you own your data"
      }),
      seeded_entry(collections, "music", "entry-music", DateTime.add(now, -180, :second), %{
        "artist" => "Nils Frahm",
        "media" => "https://soundcloud.com/nils_frahm",
        "notes" => "A reference for the next improvisation session.",
        "title" => "Community listening reference"
      })
    ]
  end

  defp seeded_entry(collections, slug, id, inserted_at, values) do
    collection = Enum.find(collections, &(&1.slug == slug))

    %{
      collection_id: collection.id,
      creator_id: nil,
      id: id,
      inserted_at: inserted_at,
      values: values
    }
  end
end
