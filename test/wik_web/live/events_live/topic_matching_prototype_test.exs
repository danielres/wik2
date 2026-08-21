defmodule WikWeb.EventsLive.TopicMatchingPrototypeTest do
  use ExUnit.Case, async: true

  alias Wik.Events.ExternalCalendarSubscription
  alias Wik.Events.ExternalEvent
  alias Wik.Tags.Tag
  alias WikWeb.EventsLive.TopicMatchingPrototype

  test "matches topic names in titles and descriptions without partial-word matches" do
    subscription = subscription("subscription")
    zouk = tag("zouk", "Zouk")
    art = tag("art", "Art")

    state =
      TopicMatchingPrototype.reconcile(TopicMatchingPrototype.empty(), [subscription], [zouk, art])

    items = [
      item(subscription, "title", "Friday ZOUK! Social", nil),
      item(subscription, "description", "Friday social", "Brazilian zouk fundamentals"),
      item(subscription, "partial", "Community party", nil)
    ]

    [title_item, description_item, partial_item] =
      TopicMatchingPrototype.apply_to_external_items(items, state)

    assert automatic_topic_ids(title_item) == ["zouk"]
    assert automatic_topic_ids(description_item) == ["zouk"]
    assert automatic_topic_ids(partial_item) == []
  end

  test "aliases, field selection, rule disabling, and subscription disabling are transient" do
    subscription = subscription("subscription")
    west_coast_swing = tag("wcs", "West Coast Swing")

    state =
      TopicMatchingPrototype.empty()
      |> TopicMatchingPrototype.reconcile([subscription], [west_coast_swing])
      |> TopicMatchingPrototype.update(subscription.id, {:add_alias, west_coast_swing.id, "WCS"})
      |> TopicMatchingPrototype.update(
        subscription.id,
        {:toggle_field, west_coast_swing.id, :description?}
      )

    title_item = item(subscription, "title", "WCS social", nil)
    description_item = item(subscription, "description", "Friday social", "WCS beginners")

    [matched_title, unmatched_description] =
      TopicMatchingPrototype.apply_to_external_items([title_item, description_item], state)

    assert automatic_topic_ids(matched_title) == [west_coast_swing.id]
    assert automatic_topic_ids(unmatched_description) == []

    rule_disabled =
      TopicMatchingPrototype.update(state, subscription.id, {:toggle_rule, west_coast_swing.id})

    assert [[], []] ==
             [title_item, description_item]
             |> TopicMatchingPrototype.apply_to_external_items(rule_disabled)
             |> Enum.map(&automatic_topic_ids/1)

    subscription_disabled =
      TopicMatchingPrototype.update(state, subscription.id, :toggle_subscription)

    assert [] ==
             title_item
             |> then(&TopicMatchingPrototype.apply_to_external_items([&1], subscription_disabled))
             |> List.first()
             |> automatic_topic_ids()
  end

  test "keeps an always-applied topic instead of adding an automatic duplicate" do
    subscription = subscription("subscription")
    blues = tag("blues", "Blues")

    state =
      TopicMatchingPrototype.reconcile(TopicMatchingPrototype.empty(), [subscription], [blues])

    existing_summary = %{
      average_relevancy: 8,
      count: 1,
      current_member_tagging: nil,
      tag: blues,
      taggings: []
    }

    [matched_item] =
      subscription
      |> item("event", "Blues night", nil)
      |> Map.put(:topic_summaries, [existing_summary])
      |> then(&TopicMatchingPrototype.apply_to_external_items([&1], state))

    assert matched_item.topic_summaries == [existing_summary]
  end

  defp automatic_topic_ids(item) do
    item.topic_summaries
    |> Enum.filter(&Map.get(&1, :automatic?, false))
    |> Enum.map(& &1.tag.id)
  end

  defp subscription(id) do
    struct!(ExternalCalendarSubscription, id: id)
  end

  defp tag(id, name) do
    struct!(Tag, id: id, name: name)
  end

  defp item(subscription, id, title, description) do
    event =
      struct!(ExternalEvent,
        description: description,
        id: id,
        starts_at: ~U[2026-09-01 18:00:00Z],
        title: title
      )

    %{
      event: event,
      id: "external:#{id}",
      subscription_id: subscription.id,
      topic_summaries: []
    }
  end
end
