defmodule Wik.Events.ExternalCalendar.TopicMatching do
  @moduledoc false

  require Ash.Query

  alias Ash.Query
  alias Wik.Events.ExternalCalendarSubscription
  alias Wik.Events.ExternalCalendarTopicRule

  @default_rule %{aliases: [], description?: true, enabled?: true, title?: true}

  def load_rules([], _scope), do: {:ok, %{}}

  def load_rules(subscriptions, scope) do
    subscription_ids = Enum.map(subscriptions, & &1.id)

    ExternalCalendarTopicRule
    |> Query.filter(subscription_id in ^subscription_ids)
    |> Query.load(:tag)
    |> Ash.read(scope: scope)
    |> case do
      {:ok, rules} -> {:ok, Enum.group_by(rules, & &1.subscription_id)}
      {:error, error} -> {:error, error}
    end
  end

  def apply_to_external_items(items, subscriptions, tags, rules_by_subscription_id) do
    subscriptions_by_id = Map.new(subscriptions, &{&1.id, &1})

    Enum.map(items, fn item ->
      subscription = Map.get(subscriptions_by_id, item.subscription_id)
      rules = Map.get(rules_by_subscription_id, item.subscription_id, [])

      apply_to_external_item(item, subscription, tags, rules)
    end)
  end

  def subscription_view(subscription, tags, rules, items) do
    rules_by_tag_id = Map.new(rules, &{&1.tag_id, &1})

    subscription_items =
      items
      |> Enum.filter(&(&1.subscription_id == subscription.id))
      |> Enum.sort_by(&{DateTime.to_unix(&1.event.starts_at, :microsecond), &1.id})

    rule_views =
      tags
      |> Enum.sort_by(&String.downcase(&1.name || ""))
      |> Enum.map(fn tag ->
        rule = rules_by_tag_id |> Map.get(tag.id) |> effective_rule()
        matches = matching_items(subscription_items, tag, rule)

        rule
        |> Map.merge(%{count: length(matches), matches: matches, tag: tag})
      end)

    active_rules = Enum.filter(rule_views, &(&1.enabled? and &1.count > 0))

    matched_event_count =
      if subscription.automatic_topic_matching do
        active_rules
        |> Enum.flat_map(& &1.matches)
        |> MapSet.new(& &1.item.id)
        |> MapSet.size()
      else
        0
      end

    %{
      enabled?: subscription.automatic_topic_matching,
      event_count: length(subscription_items),
      matched_event_count: matched_event_count,
      matched_topic_count:
        if(subscription.automatic_topic_matching, do: length(active_rules), else: 0),
      rules: rule_views,
      topic_count: length(rule_views)
    }
  end

  def update(subscription, :toggle_subscription, opts) do
    ExternalCalendarSubscription.update_topic_matching(
      subscription,
      %{automatic_topic_matching: !subscription.automatic_topic_matching},
      opts
    )
  end

  def update(subscription, action, opts) do
    scope = Keyword.fetch!(opts, :scope)
    tag_id = action_tag_id(action)

    with {:ok, stored_rule} <- get_rule(subscription.id, tag_id, scope) do
      stored_rule
      |> effective_rule()
      |> apply_action(action)
      |> persist_rule(stored_rule, subscription, tag_id, opts)
    end
  end

  def topic_matches_event?(subscription, tag, stored_rule, event) do
    rule = effective_rule(stored_rule)

    subscription.automatic_topic_matching and rule.enabled? and
      matching_fields(event, tag, rule) != []
  end

  defp apply_to_external_item(item, nil, _tags, _rules), do: item

  defp apply_to_external_item(item, subscription, tags, stored_rules) do
    if subscription.automatic_topic_matching do
      rules_by_tag_id = Map.new(stored_rules, &{&1.tag_id, &1})
      existing_summaries = Map.get(item, :topic_summaries, [])
      existing_tag_ids = MapSet.new(existing_summaries, & &1.tag.id)

      automatic_summaries =
        tags
        |> Enum.flat_map(fn tag ->
          rule = rules_by_tag_id |> Map.get(tag.id) |> effective_rule()
          fields = matching_fields(item.event, tag, rule)

          if rule.enabled? and fields != [] and
               not MapSet.member?(existing_tag_ids, tag.id) do
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

  defp effective_rule(nil), do: @default_rule

  defp effective_rule(rule) do
    %{
      aliases: rule.aliases,
      description?: rule.match_description,
      enabled?: rule.enabled,
      title?: rule.match_title
    }
  end

  defp action_tag_id({_action, tag_id}), do: tag_id
  defp action_tag_id({_action, tag_id, _value}), do: tag_id

  defp apply_action(rule, {:toggle_rule, _tag_id}) do
    %{rule | enabled?: !rule.enabled?}
  end

  defp apply_action(rule, {:toggle_field, _tag_id, field})
       when field in [:title?, :description?] do
    other_field = if field == :title?, do: :description?, else: :title?

    if Map.fetch!(rule, field) and not Map.fetch!(rule, other_field) do
      rule
    else
      Map.update!(rule, field, &(!&1))
    end
  end

  defp apply_action(rule, {:add_alias, _tag_id, value}) do
    %{rule | aliases: add_alias(rule.aliases, value)}
  end

  defp apply_action(rule, {:remove_alias, _tag_id, value}) do
    %{rule | aliases: Enum.reject(rule.aliases, &(&1 == value))}
  end

  defp get_rule(subscription_id, tag_id, scope) do
    ExternalCalendarTopicRule
    |> Query.filter(subscription_id == ^subscription_id and tag_id == ^tag_id)
    |> Ash.read_one(scope: scope)
  end

  defp persist_rule(@default_rule, nil, _subscription, _tag_id, _opts), do: {:ok, nil}

  defp persist_rule(@default_rule, stored_rule, _subscription, _tag_id, opts) do
    with :ok <- Ash.destroy(stored_rule, opts), do: {:ok, nil}
  end

  defp persist_rule(rule, nil, subscription, tag_id, opts) do
    attrs =
      rule
      |> storage_attrs()
      |> Map.merge(%{subscription_id: subscription.id, tag_id: tag_id})

    Ash.create(
      ExternalCalendarTopicRule,
      attrs,
      Keyword.put(opts, :action, :create)
    )
  end

  defp persist_rule(rule, stored_rule, _subscription, _tag_id, opts) do
    Ash.update(
      stored_rule,
      storage_attrs(rule),
      Keyword.put(opts, :action, :update)
    )
  end

  defp storage_attrs(rule) do
    %{
      aliases: rule.aliases,
      enabled: rule.enabled?,
      match_description: rule.description?,
      match_title: rule.title?
    }
  end

  defp add_alias(aliases, value) do
    value = String.trim(value)
    normalized_value = normalize(value)

    duplicate? = Enum.any?(aliases, &(normalize(&1) == normalized_value))

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
