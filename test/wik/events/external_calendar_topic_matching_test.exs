defmodule Wik.Events.ExternalCalendarTopicMatchingTest do
  use ExUnit.Case, async: true

  alias Wik.Events.ExternalCalendar.TopicMatching
  alias Wik.Events.ExternalCalendarSubscription
  alias Wik.Events.ExternalCalendarTopicRule
  alias Wik.Events.ExternalEvent
  alias Wik.Tags.Tag

  test "matches topic names in titles and descriptions without partial-word matches" do
    subscription = subscription("subscription")
    zouk = tag("zouk", "Zouk")
    art = tag("art", "Art")

    items = [
      item(subscription, "title", "Friday ZOUK! Social", nil),
      item(subscription, "description", "Friday social", "Brazilian zouk fundamentals"),
      item(subscription, "partial", "Community party", nil)
    ]

    [title_item, description_item, partial_item] =
      TopicMatching.apply_to_external_items(items, [subscription], [zouk, art], %{})

    assert automatic_topic_ids(title_item) == ["zouk"]
    assert automatic_topic_ids(description_item) == ["zouk"]
    assert automatic_topic_ids(partial_item) == []
  end

  test "applies persisted aliases, field selection, and disabling" do
    subscription = subscription("subscription")
    west_coast_swing = tag("wcs", "West Coast Swing")

    rule =
      stored_rule(subscription, west_coast_swing,
        aliases: ["WCS"],
        match_description: false
      )

    title_item = item(subscription, "title", "WCS social", nil)
    description_item = item(subscription, "description", "Friday social", "WCS beginners")

    [matched_title, unmatched_description] =
      TopicMatching.apply_to_external_items(
        [title_item, description_item],
        [subscription],
        [west_coast_swing],
        %{subscription.id => [rule]}
      )

    assert automatic_topic_ids(matched_title) == [west_coast_swing.id]
    assert automatic_topic_ids(unmatched_description) == []

    disabled_rule = %{rule | enabled: false}

    assert [[], []] ==
             [title_item, description_item]
             |> TopicMatching.apply_to_external_items(
               [subscription],
               [west_coast_swing],
               %{subscription.id => [disabled_rule]}
             )
             |> Enum.map(&automatic_topic_ids/1)

    subscription_disabled = %{subscription | automatic_topic_matching: false}

    assert [] ==
             title_item
             |> then(
               &TopicMatching.apply_to_external_items(
                 [&1],
                 [subscription_disabled],
                 [west_coast_swing],
                 %{subscription.id => [rule]}
               )
             )
             |> List.first()
             |> automatic_topic_ids()
  end

  test "keeps an always-applied topic instead of adding an automatic duplicate" do
    subscription = subscription("subscription")
    blues = tag("blues", "Blues")

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
      |> then(&TopicMatching.apply_to_external_items([&1], [subscription], [blues], %{}))

    assert matched_item.topic_summaries == [existing_summary]
  end

  defp automatic_topic_ids(item) do
    item.topic_summaries
    |> Enum.filter(&Map.get(&1, :automatic?, false))
    |> Enum.map(& &1.tag.id)
  end

  defp subscription(id) do
    struct!(ExternalCalendarSubscription, automatic_topic_matching: true, id: id)
  end

  defp tag(id, name) do
    struct!(Tag, id: id, name: name)
  end

  defp stored_rule(subscription, tag, attrs) do
    defaults = [
      aliases: [],
      enabled: true,
      match_description: true,
      match_title: true
    ]

    struct!(
      ExternalCalendarTopicRule,
      defaults
      |> Keyword.merge(attrs)
      |> Keyword.merge(subscription_id: subscription.id, tag_id: tag.id)
    )
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
