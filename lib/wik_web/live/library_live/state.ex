defmodule WikWeb.LibraryLive.State do
  @moduledoc false

  alias AshPhoenix.Form
  alias Wik.Accounts.Membership
  alias Wik.Library
  alias Wik.Library.EntryType
  alias Wik.Library.Field
  alias Wik.Library.Settings
  alias Wik.Library.TopicExclusion
  alias Wik.Library.TopicRule
  alias Wik.Tags
  alias WikWeb.LibraryLive.Schema

  @default_topic_rule %{aliases: [], enabled?: true}
  @matchable_field_types [:title, :text, :rich_text, :select, :location]

  def new do
    types = seeded_types()

    %{
      automatic_exclusions: MapSet.new(),
      automatic_topic_matching?: true,
      entries: seeded_entries(types) |> Map.new(&{&1.id, &1}),
      topic_contributions: %{},
      topic_rules: %{},
      types: types
    }
  end

  def new(scope), do: Wik.Library.snapshot(scope)

  def types_with_counts(state) do
    Enum.map(state.types, fn type ->
      Map.put(type, :entry_count, count_entries(state, type.id))
    end)
  end

  def list_entries(state) do
    state.entries
    |> Map.values()
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
  end

  def filter_entries(state, topics, topic_ids, type_ids) do
    Enum.filter(list_entries(state), fn entry ->
      type = find_type_by_id(state, entry.type_id)
      matches_type? = type_ids == [] or entry.type_id in type_ids

      matches_topic? =
        topic_ids == [] or
          Enum.any?(topic_summaries(state, entry, type, topics), &(&1.tag.id in topic_ids))

      matches_type? and matches_topic?
    end)
  end

  def assigned_topics(state, topics) do
    entry_counts = topic_entry_counts(state, topics)

    Enum.filter(topics, &Map.has_key?(entry_counts, &1.id))
  end

  def assigned_topics_with_counts(state, topics) do
    entry_counts = topic_entry_counts(state, topics)

    topics
    |> Enum.filter(&Map.has_key?(entry_counts, &1.id))
    |> Enum.map(&Map.put(&1, :entry_count, Map.fetch!(entry_counts, &1.id)))
  end

  def default_type(state), do: List.first(state.types)
  def find_type(state, slug), do: Enum.find(state.types, &(&1.slug == slug))
  def find_type_by_id(state, id), do: Enum.find(state.types, &(&1.id == id))
  def find_entry(state, id), do: Map.get(state.entries, id)

  def entries_for(state, type_id) do
    state
    |> list_entries()
    |> Enum.filter(&(&1.type_id == type_id))
  end

  def count_entries(state, type_id) do
    Enum.count(state.entries, fn {_id, entry} -> entry.type_id == type_id end)
  end

  def type_create_form(%{scope: scope} = state, draft) do
    EntryType
    |> Form.for_create(:create, as: "type", scope: scope)
    |> Form.validate(type_create_params(state, draft), errors: false)
  end

  def validate_type_create_form(state, draft, form) do
    Form.validate(form, type_create_params(state, draft))
  end

  def submit_type_create_form(state, draft, form) do
    case Form.submit(form, params: type_create_params(state, draft)) do
      {:ok, type} ->
        case persist_new_fields(type, draft.fields, state.scope) do
          :ok ->
            state = reload(state)
            {:ok, state, find_type_by_id(state, type.id)}

          {:error, error} ->
            {:error, error |> ash_error_messages() |> Enum.join(" · ")}
        end

      {:error, form} ->
        {:error, form}
    end
  end

  def type_update_form(%{scope: scope}, type) do
    Form.for_update(type, :update, as: "type", scope: scope)
  end

  def validate_type_update_form(form, params), do: Form.validate(form, params)

  def submit_type_update_form(state, type_id, form, params) do
    case Form.submit(form, params: params) do
      {:ok, _type} ->
        state = reload(state)
        {:ok, state, find_type_by_id(state, type_id)}

      {:error, form} ->
        {:error, form}
    end
  end

  def create_type(%{scope: scope} = state, draft) do
    with {:ok, attrs} <- Schema.type_attrs(stringify_keys(draft)),
         {:ok, permission} <-
           validate_entry_creation_permission(Map.get(draft, :entry_creation_permission)),
         {:ok, type} <-
           Ash.create(
             EntryType,
             Map.merge(attrs, %{
               entry_creation_permission: permission,
               slug: unique_slug(state, attrs.name)
             }),
             action: :create,
             scope: scope
           ),
         :ok <- persist_new_fields(type, draft.fields, scope) do
      state = reload(state)
      {:ok, state, find_type_by_id(state, type.id)}
    else
      {:error, message} when is_binary(message) -> {:error, message}
      {:error, error} -> {:error, error |> ash_error_messages() |> Enum.join(" · ")}
    end
  end

  def create_type(state, draft) do
    with {:ok, attrs} <- Schema.type_attrs(stringify_keys(draft)),
         {:ok, entry_creation_permission} <-
           validate_entry_creation_permission(Map.get(draft, :entry_creation_permission)) do
      type = %{
        description: attrs.description,
        entry_creation_permission: entry_creation_permission,
        fields: draft.fields,
        id: unique_id("type"),
        name: attrs.name,
        slug: unique_slug(state, attrs.name)
      }

      {:ok, %{state | types: state.types ++ [type]}, type}
    end
  end

  def update_type(%{scope: scope} = state, type_id, params) do
    with {:ok, attrs} <- Schema.type_attrs(params),
         %{} = type <- find_type_by_id(state, type_id),
         {:ok, _type} <- Ash.update(type, attrs, action: :update, scope: scope) do
      state = reload(state)
      {:ok, state, find_type_by_id(state, type_id)}
    else
      nil -> {:error, "That type is no longer available."}
      {:error, message} when is_binary(message) -> {:error, message}
      {:error, error} -> {:error, Exception.message(error)}
    end
  end

  def update_type(state, type_id, params) do
    with {:ok, attrs} <- Schema.type_attrs(params),
         %{} = type <- find_type_by_id(state, type_id) do
      type = Map.merge(type, attrs)
      {:ok, put_type(state, type), type}
    else
      nil -> {:error, "That type is no longer available."}
      {:error, message} -> {:error, message}
    end
  end

  def delete_type(%{scope: scope} = state, type_id) do
    with %{} = type <- find_type_by_id(state, type_id),
         0 <- count_entries(state, type_id),
         :ok <- Ash.destroy(type, action: :destroy, scope: scope) do
      {:ok, reload(state), type}
    else
      nil -> {:error, "That type is no longer available."}
      1 -> {:error, "This type is used by 1 entry."}
      count when is_integer(count) -> {:error, "This type is used by #{count} entries."}
      {:error, error} -> {:error, Exception.message(error)}
    end
  end

  def delete_type(state, type_id) do
    with %{} = type <- find_type_by_id(state, type_id),
         0 <- count_entries(state, type_id) do
      {:ok, %{state | types: Enum.reject(state.types, &(&1.id == type_id))}, type}
    else
      nil -> {:error, "That type is no longer available."}
      1 -> {:error, "This type is used by 1 entry."}
      count when is_integer(count) -> {:error, "This type is used by #{count} entries."}
    end
  end

  def add_field(%{scope: scope} = state, type_id, params) do
    with %{} = type <- find_type_by_id(state, type_id),
         {:ok, field_attrs} <- Schema.field_attrs(params, type.fields),
         {:ok, field} <-
           Ash.create(
             Field,
             field_attrs
             |> Map.drop([:id])
             |> Map.put(:order_key, next_field_order_key(type.fields))
             |> Map.put(:type_id, type.id),
             action: :create,
             scope: scope
           ) do
      state = reload(state)
      {:ok, state, find_type_by_id(state, type.id), field}
    else
      nil -> {:error, "That type is no longer available."}
      {:error, message} when is_binary(message) -> {:error, message}
      {:error, error} -> {:error, Exception.message(error)}
    end
  end

  def add_field(state, type_id, params) do
    with %{} = type <- find_type_by_id(state, type_id),
         {:ok, field} <- Schema.field_attrs(params, type.fields) do
      type = %{type | fields: type.fields ++ [field]}
      {:ok, put_type(state, type), type, field}
    else
      nil -> {:error, "That type is no longer available."}
      {:error, message} -> {:error, message}
    end
  end

  def update_field(%{scope: scope} = state, type_id, field_id, params) do
    with %{} = type <- find_type_by_id(state, type_id),
         %{} = existing_field <- Enum.find(type.fields, &(&1.id == field_id)),
         {:ok, field_attrs} <- Schema.field_attrs(params, type.fields, existing_field),
         :ok <- validate_field_change(state, type, existing_field, field_attrs),
         {:ok, field} <-
           Ash.update(
             existing_field,
             Map.take(field_attrs, [:label, :options, :required?, :type]),
             action: :update,
             scope: scope
           ) do
      state = reload(state)
      {:ok, state, find_type_by_id(state, type.id), field}
    else
      nil -> {:error, "That field is no longer available."}
      {:error, message} when is_binary(message) -> {:error, message}
      {:error, error} -> {:error, Exception.message(error)}
    end
  end

  def update_field(state, type_id, field_id, params) do
    with %{} = type <- find_type_by_id(state, type_id),
         %{} = existing_field <- Enum.find(type.fields, &(&1.id == field_id)),
         {:ok, field} <- Schema.field_attrs(params, type.fields, existing_field),
         :ok <- validate_field_change(state, type, existing_field, field) do
      fields = Enum.map(type.fields, &if(&1.id == field.id, do: field, else: &1))
      type = %{type | fields: fields}
      {:ok, put_type(state, type), type, field}
    else
      nil -> {:error, "That field is no longer available."}
      {:error, message} -> {:error, message}
    end
  end

  def delete_field(%{scope: scope} = state, type_id, field_id) do
    with %{} = type <- find_type_by_id(state, type_id),
         %{} = field <- Enum.find(type.fields, &(&1.id == field_id)),
         false <- field.type == :title,
         :ok <- Ash.destroy(field, action: :destroy, scope: scope),
         :ok <- remove_field_values(state, type_id, field.key) do
      state = reload(state)
      {:ok, state, find_type_by_id(state, type.id)}
    else
      nil -> {:error, "That field is no longer available."}
      true -> {:error, "The title field cannot be deleted."}
      {:error, error} -> {:error, Exception.message(error)}
    end
  end

  def delete_field(state, type_id, field_id) do
    with %{} = type <- find_type_by_id(state, type_id),
         %{} = field <- Enum.find(type.fields, &(&1.id == field_id)),
         false <- field.type == :title do
      fields = Enum.reject(type.fields, &(&1.id == field_id))
      type = %{type | fields: fields}

      entries =
        Map.new(state.entries, fn {entry_id, entry} ->
          if entry.type_id == type_id do
            {entry_id, %{entry | values: Map.delete(entry.values, field.key)}}
          else
            {entry_id, entry}
          end
        end)

      {:ok, %{put_type(state, type) | entries: entries}, type}
    else
      nil -> {:error, "That field is no longer available."}
      true -> {:error, "The title field cannot be deleted."}
    end
  end

  def move_field(%{scope: scope} = state, type_id, field_id, direction)
      when direction in [:up, :down] do
    with %{} = type <- find_type_by_id(state, type_id),
         index when is_integer(index) <- Enum.find_index(type.fields, &(&1.id == field_id)) do
      destination = index + if(direction == :up, do: -1, else: 1)

      if destination in 0..(length(type.fields) - 1) do
        sibling = Enum.at(type.fields, destination)
        field = Enum.at(type.fields, index)

        case swap_field_order(field, sibling, scope) do
          :ok ->
            state = reload(state)
            {:ok, state, find_type_by_id(state, type.id)}

          {:error, error} ->
            {:error, error |> ash_error_messages() |> Enum.join(" · ")}
        end
      else
        {:ok, state, type}
      end
    else
      nil -> {:error, "That field is no longer available."}
    end
  end

  def move_field(state, type_id, field_id, direction) when direction in [:up, :down] do
    with %{} = type <- find_type_by_id(state, type_id),
         index when is_integer(index) <- Enum.find_index(type.fields, &(&1.id == field_id)) do
      destination = if direction == :up, do: index - 1, else: index + 1

      fields =
        if destination in 0..(length(type.fields) - 1) do
          field = Enum.at(type.fields, index)

          type.fields
          |> List.delete_at(index)
          |> List.insert_at(destination, field)
        else
          type.fields
        end

      type = %{type | fields: fields}
      {:ok, put_type(state, type), type}
    else
      nil -> {:error, "That field is no longer available."}
    end
  end

  def field_usage_count(state, type_id, field) do
    state
    |> entries_for(type_id)
    |> Enum.count(fn entry -> not Schema.blank_value?(Schema.field_value(entry, field)) end)
  end

  def create_entry(state, type, creator_id, admin?, params, external_media_metadata \\ nil)

  def create_entry(
        %{scope: scope} = state,
        type,
        _creator_id,
        _admin?,
        params,
        external_media_metadata
      ) do
    case Library.create_entry(type, params, external_media_metadata, scope: scope) do
      {:ok, entry} ->
        state = reload(state)
        {:ok, state, find_entry(state, entry.id)}

      {:error, %Ash.Error.Forbidden{}} ->
        {:error, :forbidden}

      {:error, error} ->
        {:error, ash_error_messages(error)}
    end
  end

  def create_entry(state, type, creator_id, admin?, params, external_media_metadata) do
    with true <- can_create_entry?(type, admin?),
         {:ok, values} <- Schema.entry_values(type.fields, params) do
      entry = %{
        creator_id: creator_id,
        external_media_metadata: external_media_metadata,
        id: unique_id("entry"),
        inserted_at: DateTime.utc_now(),
        type_id: type.id,
        values: values
      }

      {:ok, %{state | entries: Map.put(state.entries, entry.id, entry)}, entry}
    else
      false -> {:error, :forbidden}
      {:error, errors} -> {:error, errors}
    end
  end

  def update_entry(
        state,
        type,
        entry_id,
        actor_id,
        admin?,
        params,
        external_media_metadata \\ nil
      )

  def update_entry(
        %{scope: scope} = state,
        type,
        entry_id,
        _actor_id,
        _admin?,
        params,
        external_media_metadata
      ) do
    with %{} = entry <- find_entry(state, entry_id),
         true <- entry.type_id == type.id,
         {:ok, updated_entry} <-
           Library.update_entry(entry, params, external_media_metadata, scope: scope) do
      state = reload(state)
      {:ok, state, find_entry(state, updated_entry.id)}
    else
      nil -> {:error, :not_found}
      false -> {:error, :forbidden}
      {:error, %Ash.Error.Forbidden{}} -> {:error, :forbidden}
      {:error, error} -> {:error, ash_error_messages(error)}
    end
  end

  def update_entry(
        state,
        type,
        entry_id,
        actor_id,
        admin?,
        params,
        external_media_metadata
      ) do
    with %{} = entry <- find_entry(state, entry_id),
         true <- entry.type_id == type.id,
         true <- can_manage_entry?(entry, actor_id, admin?),
         {:ok, values} <- Schema.entry_values(type.fields, params) do
      entry =
        entry
        |> Map.put(:external_media_metadata, external_media_metadata)
        |> Map.put(:values, values)

      {:ok, %{state | entries: Map.put(state.entries, entry.id, entry)}, entry}
    else
      nil -> {:error, :not_found}
      false -> {:error, :forbidden}
      {:error, errors} -> {:error, errors}
    end
  end

  def delete_entry(%{scope: scope} = state, type_id, entry_id, _actor_id, _admin?) do
    with %{} = entry <- find_entry(state, entry_id),
         true <- entry.type_id == type_id,
         {:ok, 0} <- Library.entry_reference_count(entry.id, scope: scope),
         :ok <- delete_entry_taggings(state, entry_id),
         :ok <- Library.destroy_entry(entry, scope: scope) do
      {:ok, reload(state), entry}
    else
      nil ->
        {:error, :not_found}

      false ->
        {:error, :forbidden}

      {:ok, 1} ->
        {:error, "This entry is used by 1 block. Remove that block first."}

      {:ok, count} when is_integer(count) ->
        {:error, "This entry is used by #{count} blocks. Remove those blocks first."}

      {:error, %Ash.Error.Forbidden{}} ->
        {:error, :forbidden}

      {:error, error} ->
        {:error, error}
    end
  end

  def delete_entry(state, type_id, entry_id, actor_id, admin?) do
    with %{} = entry <- find_entry(state, entry_id),
         true <- entry.type_id == type_id,
         true <- can_manage_entry?(entry, actor_id, admin?) do
      contributions =
        Map.reject(state.topic_contributions, fn {{stored_entry_id, _member_id, _topic_id},
                                                  _value} ->
          stored_entry_id == entry_id
        end)

      exclusions =
        Enum.reduce(state.automatic_exclusions, MapSet.new(), fn
          {^entry_id, _topic_id}, acc -> acc
          key, acc -> MapSet.put(acc, key)
        end)

      new_state = %{
        state
        | automatic_exclusions: exclusions,
          entries: Map.delete(state.entries, entry_id),
          topic_contributions: contributions
      }

      {:ok, new_state, entry}
    else
      nil -> {:error, :not_found}
      false -> {:error, :forbidden}
    end
  end

  def can_manage_entry?(entry, actor_id, admin?),
    do: admin? or (is_binary(actor_id) and entry.creator_id == actor_id)

  def can_create_entry?(%{entry_creation_permission: :members}, _admin?), do: true
  def can_create_entry?(%{entry_creation_permission: :admins}, admin?), do: admin?

  def topic_summaries(state, entry, type, topics, current_membership_id \\ nil) do
    manual_summaries = manual_topic_summaries(state, entry.id, topics, current_membership_id)
    manual_topic_ids = MapSet.new(manual_summaries, & &1.tag.id)

    automatic_summaries =
      if state.automatic_topic_matching? do
        topics
        |> Enum.filter(fn topic ->
          rule = topic_rule(state, topic.id)

          rule.enabled? and
            not MapSet.member?(manual_topic_ids, topic.id) and
            not MapSet.member?(state.automatic_exclusions, {entry.id, topic.id}) and
            entry_matches_topic?(entry, type, topic, rule)
        end)
        |> Enum.map(fn topic ->
          %{
            automatic?: true,
            average_relevancy: nil,
            count: 1,
            current_member_contribution: nil,
            tag: topic
          }
        end)
      else
        []
      end

    (manual_summaries ++ automatic_summaries)
    |> Enum.sort_by(fn summary ->
      {summary.automatic?, -(summary.average_relevancy || 0),
       String.downcase(summary.tag.name || "")}
    end)
  end

  def upsert_topic_contribution(state, entry_id, membership_id, topic_id, relevancy)
      when is_binary(entry_id) and is_binary(membership_id) and is_binary(topic_id) do
    if Map.has_key?(state, :scope) do
      with %{} = entry <- find_entry(state, entry_id),
           {:ok, relevancy} <- parse_relevancy(relevancy),
           {:ok, %Membership{} = membership} <-
             Ash.get(Membership, membership_id, scope: state.scope),
           {:ok, tagging} <-
             Tags.upsert_tagging(
               entry,
               membership,
               topic_id,
               %{dimensions: %{"relevancy" => relevancy}},
               scope: state.scope
             ) do
        contribution = %{
          entry_id: entry_id,
          membership_id: membership_id,
          relevancy: relevancy,
          tagging: tagging,
          topic_id: topic_id
        }

        {:ok, reload(state), contribution}
      else
        nil -> {:error, "That entry is no longer available."}
        :error -> {:error, "Choose a topic and relevance from 1 to 10."}
        {:error, error} -> {:error, error}
      end
    else
      with %{} <- find_entry(state, entry_id),
           {:ok, relevancy} <- parse_relevancy(relevancy) do
        key = {entry_id, membership_id, topic_id}

        contribution = %{
          entry_id: entry_id,
          membership_id: membership_id,
          relevancy: relevancy,
          topic_id: topic_id
        }

        new_state = %{
          state
          | automatic_exclusions: MapSet.delete(state.automatic_exclusions, {entry_id, topic_id}),
            topic_contributions: Map.put(state.topic_contributions, key, contribution)
        }

        {:ok, new_state, contribution}
      else
        nil -> {:error, "That entry is no longer available."}
        :error -> {:error, "Choose a topic and relevance from 1 to 10."}
      end
    end
  end

  def upsert_topic_contribution(_state, _entry_id, _membership_id, _topic_id, _relevancy),
    do: {:error, "Choose a topic and relevance from 1 to 10."}

  def error_message(message) when is_binary(message), do: message

  def error_message(error) do
    error
    |> ash_error_messages()
    |> Enum.join(" · ")
  end

  def remove_topic_contribution(state, entry_id, membership_id, topic_id) do
    key = {entry_id, membership_id, topic_id}

    if Map.has_key?(state, :scope) do
      case Map.get(state.topic_contributions, key) do
        %{tagging: tagging} ->
          case Ash.destroy(tagging, scope: state.scope) do
            :ok -> {:ok, reload(state)}
            {:error, error} -> {:error, error}
          end

        nil ->
          {:error, :not_found}
      end
    else
      if Map.has_key?(state.topic_contributions, key) do
        {:ok, %{state | topic_contributions: Map.delete(state.topic_contributions, key)}}
      else
        {:error, :not_found}
      end
    end
  end

  def dismiss_automatic_topic(%{scope: scope} = state, entry_id, topic_id) do
    case Ash.create(
           TopicExclusion,
           %{entry_id: entry_id, tag_id: topic_id},
           action: :create,
           scope: scope
         ) do
      {:ok, _exclusion} -> reload(state)
      {:error, _error} -> state
    end
  end

  def dismiss_automatic_topic(state, entry_id, topic_id) do
    %{state | automatic_exclusions: MapSet.put(state.automatic_exclusions, {entry_id, topic_id})}
  end

  def toggle_automatic_topic_matching(%{scope: scope} = state) do
    settings = Ash.read_one!(Settings, scope: scope)

    case Ash.update(
           settings,
           %{automatic_topic_matching: not settings.automatic_topic_matching},
           action: :update,
           scope: scope
         ) do
      {:ok, _settings} -> reload(state)
      {:error, _error} -> state
    end
  end

  def toggle_automatic_topic_matching(state) do
    %{state | automatic_topic_matching?: not state.automatic_topic_matching?}
  end

  def topic_rule(state, topic_id), do: Map.get(state.topic_rules, topic_id, @default_topic_rule)

  def toggle_topic_rule(%{scope: _scope} = state, topic_id) do
    rule = topic_rule(state, topic_id)
    persist_topic_rule(state, topic_id, %{rule | enabled?: not rule.enabled?})
  end

  def toggle_topic_rule(state, topic_id) do
    rule = topic_rule(state, topic_id)
    put_topic_rule(state, topic_id, %{rule | enabled?: not rule.enabled?})
  end

  def add_topic_alias(%{scope: _scope} = state, topic_id, value) do
    value = String.trim(value)
    rule = topic_rule(state, topic_id)
    normalized_value = normalize(value)
    duplicate? = Enum.any?(rule.aliases, &(normalize(&1) == normalized_value))

    if normalized_value == "" or duplicate? do
      state
    else
      persist_topic_rule(state, topic_id, %{rule | aliases: rule.aliases ++ [value]})
    end
  end

  def add_topic_alias(state, topic_id, value) do
    value = String.trim(value)
    rule = topic_rule(state, topic_id)
    normalized_value = normalize(value)
    duplicate? = Enum.any?(rule.aliases, &(normalize(&1) == normalized_value))

    if normalized_value == "" or duplicate? do
      state
    else
      put_topic_rule(state, topic_id, %{rule | aliases: rule.aliases ++ [value]})
    end
  end

  def remove_topic_alias(%{scope: _scope} = state, topic_id, value) do
    rule = topic_rule(state, topic_id)

    persist_topic_rule(state, topic_id, %{
      rule
      | aliases: Enum.reject(rule.aliases, &(&1 == value))
    })
  end

  def remove_topic_alias(state, topic_id, value) do
    rule = topic_rule(state, topic_id)
    put_topic_rule(state, topic_id, %{rule | aliases: Enum.reject(rule.aliases, &(&1 == value))})
  end

  def topic_match_count(state, topic, _topics) do
    rule = topic_rule(state, topic.id)

    if state.automatic_topic_matching? and rule.enabled? do
      state
      |> list_entries()
      |> Enum.count(fn entry ->
        type = find_type_by_id(state, entry.type_id)
        entry_matches_topic?(entry, type, topic, rule)
      end)
    else
      0
    end
  end

  defp topic_entry_counts(state, topics) do
    state
    |> list_entries()
    |> Enum.reduce(%{}, fn entry, entry_counts ->
      type = find_type_by_id(state, entry.type_id)

      state
      |> topic_summaries(entry, type, topics)
      |> Enum.reduce(entry_counts, fn summary, entry_counts ->
        Map.update(entry_counts, summary.tag.id, 1, &(&1 + 1))
      end)
    end)
  end

  defp manual_topic_summaries(state, entry_id, topics, current_membership_id) do
    topics_by_id = Map.new(topics, &{&1.id, &1})

    state.topic_contributions
    |> Map.values()
    |> Enum.filter(&(&1.entry_id == entry_id))
    |> Enum.group_by(& &1.topic_id)
    |> Enum.flat_map(fn {topic_id, contributions} ->
      case Map.get(topics_by_id, topic_id) do
        nil ->
          []

        topic ->
          levels = Enum.map(contributions, & &1.relevancy)

          [
            %{
              automatic?: false,
              average_relevancy: round(Enum.sum(levels) / length(levels)),
              count: length(contributions),
              current_member_contribution:
                Enum.find(contributions, &(&1.membership_id == current_membership_id)),
              tag: topic
            }
          ]
      end
    end)
  end

  defp entry_matches_topic?(entry, type, topic, rule) do
    phrases = [topic.name | rule.aliases]

    Enum.any?(type.fields, fn field ->
      field.type in @matchable_field_types and
        phrase_match?(Schema.field_value(entry, field), phrases)
    end)
  end

  defp phrase_match?(text, phrases) when is_binary(text) do
    normalized_text = " " <> normalize(text) <> " "

    Enum.any?(phrases, fn phrase ->
      normalized_phrase = normalize(phrase)
      normalized_phrase != "" and String.contains?(normalized_text, " #{normalized_phrase} ")
    end)
  end

  defp phrase_match?(_text, _phrases), do: false

  defp normalize(value) when is_binary(value) do
    value
    |> String.normalize(:nfkc)
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}]+/u, " ")
    |> String.trim()
  end

  defp normalize(_value), do: ""

  defp put_topic_rule(state, topic_id, @default_topic_rule),
    do: %{state | topic_rules: Map.delete(state.topic_rules, topic_id)}

  defp put_topic_rule(state, topic_id, rule),
    do: %{state | topic_rules: Map.put(state.topic_rules, topic_id, rule)}

  defp parse_relevancy(value) when is_integer(value) and value in 1..10, do: {:ok, value}

  defp parse_relevancy(value) when is_binary(value) do
    case Integer.parse(value) do
      {level, ""} when level in 1..10 -> {:ok, level}
      _other -> :error
    end
  end

  defp parse_relevancy(_value), do: :error

  defp validate_field_change(state, type, existing_field, field) do
    usage_count = field_usage_count(state, type.id, existing_field)

    cond do
      existing_field.type == :title and field.type != :title ->
        {:error, "The title field type cannot be changed."}

      existing_field.type == :title and not field.required? ->
        {:error, "The title field is always required."}

      existing_field.type != field.type and usage_count > 0 ->
        {:error, "Clear this field from every entry before changing its type."}

      not existing_field.required? and field.required? and
          entries_missing_field?(state, type.id, existing_field) ->
        {:error, "Fill this field in every entry before making it required."}

      existing_field.type == :select and field.type == :select and
          used_select_options_removed?(state, type.id, existing_field, field) ->
        {:error, "A select option still used by an entry cannot be removed."}

      true ->
        :ok
    end
  end

  defp entries_missing_field?(state, type_id, field) do
    state
    |> entries_for(type_id)
    |> Enum.any?(fn entry -> Schema.blank_value?(Schema.field_value(entry, field)) end)
  end

  defp used_select_options_removed?(state, type_id, existing_field, field) do
    removed_options = existing_field.options -- field.options

    state
    |> entries_for(type_id)
    |> Enum.any?(fn entry -> Schema.field_value(entry, existing_field) in removed_options end)
  end

  defp put_type(state, type) do
    %{state | types: Enum.map(state.types, &if(&1.id == type.id, do: type, else: &1))}
  end

  defp unique_slug(state, name) do
    base =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/u, "-")
      |> String.trim("-")
      |> case do
        "" -> "type"
        slug -> slug
      end

    used_slugs = MapSet.new(state.types, & &1.slug)

    Stream.iterate(1, &(&1 + 1))
    |> Enum.find_value(fn
      1 -> if not MapSet.member?(used_slugs, base), do: base
      suffix -> if not MapSet.member?(used_slugs, "#{base}-#{suffix}"), do: "#{base}-#{suffix}"
    end)
  end

  defp stringify_keys(map), do: Map.new(map, fn {key, value} -> {to_string(key), value} end)

  defp type_create_params(state, draft) do
    %{
      "description" => Map.get(draft, :description, ""),
      "entry_creation_permission" => Map.get(draft, :entry_creation_permission),
      "name" => Map.get(draft, :name, ""),
      "slug" => unique_slug(state, Map.get(draft, :name, ""))
    }
  end

  defp validate_entry_creation_permission("members"), do: {:ok, :members}
  defp validate_entry_creation_permission("admins"), do: {:ok, :admins}

  defp validate_entry_creation_permission(_permission),
    do: {:error, "Choose who can add entries."}

  defp ash_error_messages(error) do
    error
    |> Ash.Error.to_error_class()
    |> Map.fetch!(:errors)
    |> Enum.map(&ash_error_message/1)
  end

  defp ash_error_message(%Ash.Error.Changes.Required{field: field}) do
    "#{field |> to_string() |> Phoenix.Naming.humanize()} is required."
  end

  defp ash_error_message(error), do: Exception.message(error)

  defp delete_entry_taggings(state, entry_id) do
    state.topic_contributions
    |> Map.values()
    |> Enum.filter(&(&1.entry_id == entry_id))
    |> Enum.reduce_while(:ok, fn contribution, :ok ->
      case Ash.destroy(contribution.tagging, scope: state.scope) do
        :ok -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp next_field_order_key(fields) do
    fields
    |> length()
    |> Kernel.+(1)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  defp persist_new_fields(type, fields, scope) do
    fields
    |> Enum.with_index(1)
    |> Enum.reduce_while(:ok, fn {field, index}, :ok ->
      attrs =
        field
        |> Map.drop([:id])
        |> Map.put(:order_key, String.pad_leading(Integer.to_string(index), 6, "0"))
        |> Map.put(:type_id, type.id)

      case Ash.create(Field, attrs, action: :create, scope: scope) do
        {:ok, _field} -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp persist_topic_rule(state, topic_id, rule) do
    result =
      case Map.get(rule, :record) do
        nil ->
          Ash.create(
            TopicRule,
            %{aliases: rule.aliases, enabled: rule.enabled?, tag_id: topic_id},
            action: :create,
            scope: state.scope
          )

        record ->
          Ash.update(
            record,
            %{aliases: rule.aliases, enabled: rule.enabled?},
            action: :update,
            scope: state.scope
          )
      end

    case result do
      {:ok, _rule} -> reload(state)
      {:error, _error} -> state
    end
  end

  defp reload(%{scope: scope}), do: Library.snapshot(scope)

  defp remove_field_values(state, type_id, field_key) do
    state.entries
    |> Map.values()
    |> Enum.filter(&(&1.type_id == type_id))
    |> Enum.reduce_while(:ok, fn entry, :ok ->
      case Ash.update(
             entry,
             %{values: Map.delete(entry.values, field_key)},
             action: :update,
             scope: state.scope
           ) do
        {:ok, _entry} -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp swap_field_order(field, sibling, scope) do
    field_order = field.order_key
    sibling_order = sibling.order_key
    temporary_order = "moving-#{Ash.UUID.generate()}"

    with {:ok, field} <-
           Ash.update(field, %{order_key: temporary_order}, action: :update, scope: scope),
         {:ok, _sibling} <-
           Ash.update(sibling, %{order_key: field_order}, action: :update, scope: scope),
         {:ok, _field} <-
           Ash.update(field, %{order_key: sibling_order}, action: :update, scope: scope) do
      :ok
    end
  end

  defp unique_id(prefix), do: "#{prefix}-#{System.unique_integer([:monotonic, :positive])}"

  defp seeded_types do
    Schema.built_in_templates()
    |> Enum.reject(&(&1.id == "custom"))
    |> Enum.map(fn template ->
      draft = Schema.instantiate_template(template)

      %{
        description: draft.description,
        entry_creation_permission: :members,
        fields: draft.fields,
        id: "type-#{template.id}",
        name: template.name,
        slug: template.id
      }
    end)
  end

  defp seeded_entries(types) do
    now = DateTime.utc_now()

    playlist_url =
      "https://www.youtube.com/playlist?list=PL-ZQIvQFPv4LYaNhtbleNaepGSGsuzQyp"

    # 
    [
      seeded_entry(types, "place", "entry-place", now, %{
        "location" => "Spreeacker, Wilhelmine-Gemberg-Weg 12, Berlin",
        "name" => "Spreeacker",
        "notes" => "Community garden and open-air dance location.",
        "phone" => "+49 30 123456",
        "website" => "https://example.org/spreeacker"
      }),
      seeded_entry(
        types,
        "external-media",
        "entry-playlist",
        DateTime.add(now, -20, :second),
        %{
          "creator" => "8-bit Music Theory",
          "duration" => "",
          "media" => playlist_url,
          "notes" => "",
          "title" => "Modes Analysis Videos"
        },
        %{
          item_count: 8,
          kind: :playlist,
          playlist_items: [
            %{title: "LOCRIAN doesn't have to be S p O o K y", video_id: "tbRdHktBv58"},
            %{title: "How to Use the LYDIAN Mode", video_id: "XElvBrpaUP8"},
            %{title: "The MIXOLYDIAN Mode is Really Kind of Goofy", video_id: "strpCnUKs_g"},
            %{title: "The PHRYGIAN Mode Feels THREATENING", video_id: "tWthNcF_4Uk"},
            %{
              title: "The DORIAN Mode Feels MYSTERIOUS (among other things)",
              video_id: "SbRD3tPipNw"
            },
            %{title: "The AEOLIAN Mode Feels Devastating", video_id: "UFqfSTdg5Xg"},
            %{title: "The Ionian Mode Feels RELAXING", video_id: "RXxU324nCEY"},
            %{title: "What are the Melodic Minor Modes?", video_id: "E_mto_Dkpo0"}
          ],
          provider: :youtube,
          source_url: playlist_url,
          thumbnail_url: "https://i.ytimg.com/vi/tbRdHktBv58/hqdefault.jpg"
        }
      ),
      seeded_entry(
        types,
        "external-media",
        "entry-video-downtempo",
        DateTime.add(now, -10, :second),
        %{
          "creator" => "Tom",
          "duration" => "14:46",
          "media" => "https://www.youtube.com/watch?v=UuU-Go8GoeY&t=886s",
          "notes" =>
            "The platypus (Ornithorhynchus anatinus), sometimes referred to as the duck-billed platypus, is a semiaquatic, egg-laying mammal endemic to eastern Australia, including Tasmania. The platypus is the sole living representative of its family Ornithorhynchidae and genus Ornithorhynchus, though a number of related species appear in the fossil record. Together with the four species of echidna, it is one of the five extant species of monotremes, mammals that lay eggs instead of giving birth to live young. Like other monotremes, the platypus has a sense of electrolocation, which it uses to detect prey in water while its eyes, ears and nostrils are closed. It is one of the few species of venomous mammals, as the male platypus has a spur on each hind foot that delivers an extremely painful venom.",
          "title" =>
            "Downtempo music  The platypus (Ornithorhynchus anatinus), sometimes referred to as the duck-billed platypus, is a semiaquatic, egg-laying mammal endemic to eastern Australia, including Tasmania. The  "
        }
      ),
      seeded_entry(types, "contact", "entry-contact", DateTime.add(now, -60, :second), %{
        "email" => "hello@example.org",
        "name" => "Dr. Ada Rivera",
        "notes" => "English and German consultations.",
        "organization" => "Community Health Practice",
        "phone" => "+49 30 654321",
        "role" => "General practitioner",
        "website" => "https://example.org/health"
      }),
      seeded_entry(types, "external-media", "entry-video", DateTime.add(now, -120, :second), %{
        "creator" => "Local-first community",
        "media" => "https://www.youtube.com/watch?v=BvlGs25tCxI",
        "notes" =>
          "A gentle introduction to tools that keep communities in control of their data.",
        "title" => "Local-first software: you own your data"
      }),
      seeded_entry(types, "external-media", "entry-music", DateTime.add(now, -180, :second), %{
        "creator" => "Nils Frahm",
        "media" => "https://soundcloud.com/nils_frahm",
        "notes" => "A dance reference for the next improvisation session. Coming in Berlin",
        "title" => "Sheep in Black and White"
      }),
      seeded_entry(
        types,
        "external-media",
        "entry-music-tfw",
        DateTime.add(now, -190, :second),
        %{
          "creator" => "Tales from Within",
          "media" => "https://soundcloud.com/tales-from-within/impossible-suns",
          "notes" => "Inner and Outer space Travels",
          "title" => "Impossible Suns"
        }
      ),
      seeded_entry(types, "place", "entry-place-garden", DateTime.add(now, -200, :second), %{
        "location" => "Tempelhofer Garten, Berlin",
        "name" => "Communal garden Tempelhof",
        "notes" => "Community garden and open-air dance location.",
        "phone" => "+49 30 123456",
        "website" => "https://example.org/garden"
      }),
      seeded_entry(types, "place", "entry-place-garden2", DateTime.add(now, -200, :second), %{
        "location" => "Tempelhofer Garten 2, Berlin",
        "name" => "Communal garden Tempelhof 2",
        "notes" => "Community garden and open-air dance location.",
        "phone" => "+49 30 123456",
        "website" => "https://example.org/garden"
      })
    ]
  end

  defp seeded_entry(types, slug, id, inserted_at, values, external_media_metadata \\ nil) do
    type = Enum.find(types, &(&1.slug == slug))

    %{
      creator_id: nil,
      external_media_metadata: external_media_metadata,
      id: id,
      inserted_at: inserted_at,
      type_id: type.id,
      values: values
    }
  end
end
