defmodule Wik.Activity.NotificationMapperTest do
  use Wik.DataCase, async: false

  import Wik.TestGenerators

  alias Wik.Activity.Entry
  alias Wik.Activity.NotificationMapper
  alias Wik.Blocks
  alias Wik.Events
  alias Wik.Events.Event
  alias Wik.Events.EventPublication
  alias Wik.Scope
  alias Wik.Tags
  alias Wik.Wiki

  require Ash.Query

  test "records and collapses topic updates" do
    %{owner: owner, scope: scope, space: space} = space_fixture()

    assert {:ok, tag} = Tags.create_tag("gardening", "Gardening", scope: scope)
    assert {:ok, tag} = Tags.update_tag(tag, %{name: "Garden"}, action: :update, scope: scope)

    assert {:ok, _tag} =
             Tags.update_tag(tag, %{name: "Community garden"}, action: :update, scope: scope)

    entries = list_entries(space)
    created = Enum.find(entries, &(&1.kind == :topic_created))
    updated = Enum.find(entries, &(&1.kind == :topic_updated))

    assert created.category == :topics
    assert created.subject_label == "Gardening"
    assert updated.subject_label == "Community garden"
    assert updated.occurrence_count == 2
    assert updated.actor_label == to_string(owner)
  end

  test "collapses participation changes and keeps the latest social state" do
    %{scope: owner_scope, space: space} = space_fixture()
    member = generate(user())
    membership = generate(membership(space: space, user: member, type: :member))
    member_scope = %Scope{actor: member, tenant: space}

    assert {:ok, event} =
             Ash.create(Event, event_attrs(), action: :create, scope: owner_scope)

    publication =
      EventPublication
      |> Ash.Query.filter(event_id == ^event.id and target_space_id == ^space.id)
      |> Ash.read_one!(scope: owner_scope)

    assert {:ok, _participation} =
             Events.record_interest(
               publication,
               %{extra_info: "I can help set up", interest: 9},
               scope: member_scope
             )

    assert {:ok, _participation} =
             Events.record_interest(
               publication,
               %{extra_info: "Still deciding", interest: 2},
               scope: member_scope
             )

    assert {:ok, nil} =
             Events.record_interest(
               publication,
               %{extra_info: "", interest: 0},
               scope: member_scope
             )

    participation_entries =
      space
      |> list_entries()
      |> Enum.filter(&(&1.kind in [:event_participation_changed, :event_participation_removed]))

    assert [entry] = participation_entries
    assert entry.kind == :event_participation_removed
    assert entry.category == :events
    assert entry.actor_membership_id == membership.id
    assert entry.occurrence_count == 3
    assert entry.subject_label == event.title
    assert entry.metadata["note"] == nil
  end

  test "gives untitled events a stable feed label" do
    %{space: space} = space_fixture()
    event = %Event{id: Ash.UUIDv7.generate(), space_id: space.id, title: nil}

    notification = %Ash.Notifier.Notification{
      action: %{name: :create},
      data: event,
      resource: Event
    }

    assert [%{subject_label: "Untitled event"}] = NotificationMapper.map(notification)
  end

  test "translates block changes into a page update" do
    %{scope: scope, space: space} = space_fixture()

    assert {:ok, _node, page} = Wiki.ensure_page_and_node_at_path("home", scope: scope)

    assert {:ok, block} =
             Blocks.create_space_owned_block_on_page(
               space,
               page,
               %{type: :text},
               scope: scope
             )

    assert {:ok, _block} = Blocks.update_block(block, %{"text" => "Latest news"}, scope: scope)

    page_updates =
      space
      |> list_entries()
      |> Enum.filter(&(&1.kind == :page_updated))

    assert [entry] = page_updates
    assert entry.category == :wiki
    assert entry.subject_id == page.id
    assert entry.subject_label == "Home"
    assert entry.occurrence_count == 2
  end

  test "categorizes member topic assignments as member activity" do
    %{owner: owner, scope: scope, space: space} = space_fixture()

    owner_membership =
      Wik.Accounts.get_membership(space.id, owner.id)
      |> then(fn {:ok, membership} -> membership end)

    assert {:ok, tag} = Tags.create_tag("gardeners", "Gardeners", scope: scope)

    assert {:ok, tagging} =
             Tags.upsert_tagging(
               owner_membership,
               owner_membership,
               tag.id,
               %{description: "Coordinates the garden", dimensions: %{interest: 8}},
               scope: scope
             )

    assert {:ok, updated_tagging} =
             Tags.upsert_tagging(
               owner_membership,
               owner_membership,
               tag.id,
               %{description: "Leads the garden", dimensions: %{interest: 10}},
               scope: scope
             )

    assert updated_tagging.id == tagging.id

    assert {:ok, removed_tagging} =
             Tags.remove_tagging(owner_membership, owner_membership, tag.id, scope: scope)

    assert removed_tagging.id == tagging.id

    member_tag_entries =
      space
      |> list_entries()
      |> Enum.filter(&(&1.kind in [:member_tag_added, :member_tag_updated, :member_tag_removed]))

    assert Enum.sort(Enum.map(member_tag_entries, & &1.kind)) ==
             Enum.sort([:member_tag_added, :member_tag_removed, :member_tag_updated])

    assert Enum.all?(member_tag_entries, &(&1.category == :members))
    assert Enum.all?(member_tag_entries, &(&1.metadata["tag_label"] == "Gardeners"))
  end

  test "keeps a member snapshot after the membership is deleted" do
    %{scope: scope, space: space} = space_fixture()
    member = generate(user())

    membership =
      generate(
        membership(space: space, user: member, type: :member, username: "departing-member")
      )

    assert :ok = Ash.destroy(membership, authorize?: false, scope: scope)

    entry =
      space
      |> list_entries()
      |> Enum.find(&(&1.kind == :member_left))

    assert entry.actor_membership_id == nil
    assert entry.actor_label == "departing-member"
    assert entry.subject_label == "departing-member"
  end

  test "categorizes space metadata changes as other and ignores last-seen updates" do
    %{owner: owner, scope: scope, space: space} = space_fixture()

    assert {:ok, space} = Ash.update(space, %{description: "First"}, scope: scope)
    assert {:ok, _space} = Ash.update(space, %{description: "Second"}, scope: scope)
    assert :ok = Wik.Accounts.mark_membership_seen(space.id, owner.id)

    entries = list_entries(space)
    assert [entry] = Enum.filter(entries, &(&1.kind == :space_updated))
    assert entry.category == :other
    assert entry.occurrence_count == 2
    refute Enum.any?(entries, &(&1.kind == :member_profile_updated))
  end

  defp space_fixture do
    owner = generate(user())
    space = generate(space(author: owner))
    generate(membership(space: space, user: owner, type: :owner))
    %{owner: owner, scope: %Scope{actor: owner, tenant: space}, space: space}
  end

  defp list_entries(space) do
    Entry
    |> Ash.Query.sort(occurred_at: :desc)
    |> Ash.read!(authorize?: false, tenant: space.id)
  end

  defp event_attrs do
    %{
      all_day: false,
      ends_at_time: "20:00",
      ends_on: future_date_string(30),
      location: "Community Hall",
      starts_at_time: "18:00",
      starts_on: future_date_string(30),
      title: "Shared dinner",
      tz: "Etc/UTC"
    }
  end
end
