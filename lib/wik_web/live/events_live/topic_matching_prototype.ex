defmodule WikWeb.EventsLive.TopicMatchingPrototype do
  @moduledoc false

  def empty do
    %{subscriptions: %{}, tags_by_id: %{}}
  end

  def reconcile(state, subscriptions, tags) do
    state = state || empty()
    tags_by_id = Map.new(tags, &{&1.id, &1})

    subscription_states =
      Map.new(subscriptions, fn subscription ->
        existing = get_in(state, [:subscriptions, subscription.id]) || %{}
        existing_rules = Map.get(existing, :rules, %{})

        rules =
          Map.new(tags, fn tag ->
            {tag.id, Map.get(existing_rules, tag.id, default_rule())}
          end)

        {subscription.id,
         %{
           enabled?: Map.get(existing, :enabled?, true),
           rules: rules
         }}
      end)

    %{subscriptions: subscription_states, tags_by_id: tags_by_id}
  end

  def update(state, subscription_id, :toggle_subscription) do
    update_in(state, [:subscriptions, subscription_id, :enabled?], &(!&1))
  end

  def update(state, subscription_id, {:toggle_rule, tag_id}) do
    update_in(state, [:subscriptions, subscription_id, :rules, tag_id, :enabled?], &(!&1))
  end

  def update(state, subscription_id, {:toggle_field, tag_id, field})
      when field in [:title?, :description?] do
    rule = get_in(state, [:subscriptions, subscription_id, :rules, tag_id])
    other_field = if field == :title?, do: :description?, else: :title?

    if Map.fetch!(rule, field) and not Map.fetch!(rule, other_field) do
      state
    else
      update_in(
        state,
        [:subscriptions, subscription_id, :rules, tag_id, field],
        &(!&1)
      )
    end
  end

  def update(state, subscription_id, {:add_alias, tag_id, value}) do
    value = String.trim(value)
    tag = Map.get(state.tags_by_id, tag_id)

    aliases =
      state
      |> get_in([:subscriptions, subscription_id, :rules, tag_id, :aliases])
      |> add_alias(value, tag)

    put_in(state, [:subscriptions, subscription_id, :rules, tag_id, :aliases], aliases)
  end

  def update(state, subscription_id, {:remove_alias, tag_id, value}) do
    update_in(
      state,
      [:subscriptions, subscription_id, :rules, tag_id, :aliases],
      &Enum.reject(&1, fn alias_value -> alias_value == value end)
    )
  end

  def apply_to_external_items(items, state) do
    Enum.map(items, &apply_to_external_item(&1, state))
  end

  def subscription_view(state, subscription_id, items) do
    subscription_state =
      Map.get(state.subscriptions, subscription_id, %{enabled?: true, rules: %{}})

    subscription_items =
      items
      |> Enum.filter(&(&1.subscription_id == subscription_id))
      |> Enum.sort_by(&{DateTime.to_unix(&1.event.starts_at, :microsecond), &1.id})

    rules =
      state.tags_by_id
      |> Map.values()
      |> Enum.sort_by(&String.downcase(&1.name || ""))
      |> Enum.map(fn tag ->
        rule = Map.get(subscription_state.rules, tag.id, default_rule())
        matches = matching_items(subscription_items, tag, rule)

        rule
        |> Map.merge(%{count: length(matches), matches: matches, tag: tag})
      end)

    active_rules = Enum.filter(rules, &(&1.enabled? and &1.count > 0))

    matched_event_count =
      if subscription_state.enabled? do
        active_rules
        |> Enum.flat_map(& &1.matches)
        |> MapSet.new(& &1.item.id)
        |> MapSet.size()
      else
        0
      end

    %{
      enabled?: subscription_state.enabled?,
      event_count: length(subscription_items),
      matched_event_count: matched_event_count,
      matched_topic_count: if(subscription_state.enabled?, do: length(active_rules), else: 0),
      rules: rules,
      topic_count: length(rules)
    }
  end

  defp apply_to_external_item(item, state) do
    subscription_state = Map.get(state.subscriptions, item.subscription_id)

    if subscription_state && subscription_state.enabled? do
      existing_summaries = Map.get(item, :topic_summaries, [])
      existing_tag_ids = MapSet.new(existing_summaries, & &1.tag.id)

      automatic_summaries =
        subscription_state.rules
        |> Enum.flat_map(fn {tag_id, rule} ->
          tag = Map.get(state.tags_by_id, tag_id)
          fields = matching_fields(item.event, tag, rule)

          if tag && rule.enabled? && fields != [] &&
               not MapSet.member?(existing_tag_ids, tag_id) do
            [automatic_summary(tag, fields)]
          else
            []
          end
        end)
        |> Enum.sort_by(&String.downcase(&1.tag.name || ""))

      Map.put(item, :topic_summaries, existing_summaries ++ automatic_summaries)
    else
      item
    end
  end

  defp matching_items(items, tag, rule) do
    Enum.flat_map(items, fn item ->
      case matching_fields(item.event, tag, rule) do
        [] -> []
        fields -> [%{fields: fields, item: item}]
      end
    end)
  end

  defp matching_fields(_event, nil, _rule), do: []

  defp matching_fields(event, tag, rule) do
    phrases = [tag.name | rule.aliases]

    []
    |> maybe_add_matching_field(:title, event.title, rule.title?, phrases)
    |> maybe_add_matching_field(:description, event.description, rule.description?, phrases)
    |> Enum.reverse()
  end

  defp maybe_add_matching_field(fields, _field, _text, false, _phrases), do: fields

  defp maybe_add_matching_field(fields, field, text, true, phrases) do
    if phrase_match?(text, phrases), do: [field | fields], else: fields
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

  defp default_rule do
    %{aliases: [], description?: true, enabled?: true, title?: true}
  end

  defp add_alias(aliases, "", _tag), do: aliases

  defp add_alias(aliases, value, tag) do
    normalized_value = normalize(value)
    normalized_topic_name = normalize(tag && tag.name)

    duplicate? =
      normalized_value == normalized_topic_name or
        Enum.any?(aliases, &(normalize(&1) == normalized_value))

    if normalized_value == "" or duplicate?, do: aliases, else: aliases ++ [value]
  end

  defp automatic_summary(tag, fields) do
    %{
      automatic?: true,
      average_relevancy: nil,
      count: 1,
      current_member_tagging: nil,
      matched_fields: fields,
      tag: tag,
      taggings: []
    }
  end
end
