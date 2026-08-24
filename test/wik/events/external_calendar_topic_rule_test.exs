defmodule Wik.Events.ExternalCalendarTopicRuleTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.Membership
  alias Wik.Events.ExternalCalendar.TopicMatching
  alias Wik.Events.ExternalCalendarSubscription
  alias Wik.Events.ExternalCalendarTopicRule
  alias Wik.Scope
  alias Wik.Tags

  test "stores only deviations from automatic matching defaults" do
    %{scope: scope, subscription: subscription, tag: tag} = fixture()

    assert {:ok, %ExternalCalendarTopicRule{} = rule} =
             TopicMatching.update(subscription, {:add_alias, tag.id, "  WCS  "}, scope: scope)

    assert rule.aliases == ["WCS"]
    assert rule.enabled
    assert rule.match_description
    assert rule.match_title

    assert {:ok, nil} =
             TopicMatching.update(subscription, {:remove_alias, tag.id, "WCS"}, scope: scope)

    assert [] == Ash.read!(ExternalCalendarTopicRule, scope: scope)

    assert {:ok, %ExternalCalendarTopicRule{enabled: false}} =
             TopicMatching.update(subscription, {:toggle_rule, tag.id}, scope: scope)
  end

  test "persists the subscription-level automatic matching switch" do
    %{scope: scope, subscription: subscription} = fixture()

    assert subscription.automatic_topic_matching

    assert {:ok, updated_subscription} =
             TopicMatching.update(subscription, :toggle_subscription, scope: scope)

    refute updated_subscription.automatic_topic_matching

    reloaded = Ash.get!(ExternalCalendarSubscription, subscription.id, scope: scope)
    refute reloaded.automatic_topic_matching
  end

  test "rejects rules that disable both matching fields" do
    %{scope: scope, subscription: subscription, tag: tag} = fixture()

    assert {:error, %Ash.Error.Invalid{} = error} =
             Ash.create(
               ExternalCalendarTopicRule,
               %{
                 match_description: false,
                 match_title: false,
                 subscription_id: subscription.id,
                 tag_id: tag.id
               },
               action: :create,
               scope: scope
             )

    assert Exception.message(error) =~ "at least one match field is required"
  end

  test "regular members can read rules but cannot manage them" do
    %{member: member, scope: owner_scope, space: space, subscription: subscription, tag: tag} =
      fixture()

    {:ok, rule} = TopicMatching.update(subscription, {:toggle_rule, tag.id}, scope: owner_scope)
    member_scope = scope(member, space)

    assert Ash.can?({rule, :read}, member_scope)
    refute Ash.can?({rule, :update}, member_scope)
    refute Ash.can?({rule, :destroy}, member_scope)
    refute Ash.can?({ExternalCalendarTopicRule, :create}, member_scope)
  end

  defp fixture do
    owner = generate(user())
    member = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    add_membership(space, member, :member)
    grant_active_telegram_access(space, member)
    scope = scope(owner, space)
    {:ok, tag} = Tags.create_tag("west-coast-swing", "West Coast Swing", scope: scope)

    {:ok, subscription} =
      ExternalCalendarSubscription.create(
        %{ics_url: "https://calendar.example.test/community.ics"},
        scope: scope
      )

    %{member: member, scope: scope, space: space, subscription: subscription, tag: tag}
  end

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
  end

  defp scope(actor, tenant), do: %Scope{actor: actor, tenant: tenant}
end
