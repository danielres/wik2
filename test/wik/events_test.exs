defmodule Wik.EventsTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Ash.Query
  alias Wik.Accounts.GroupUserRelation
  alias Wik.Events
  alias Wik.Events.EventPublication
  alias Wik.Scope

  describe "create_event/2" do
    test "creates the event and origin publication for an owner" do
      owner = generate(user())
      group = generate(group(author: owner))
      add_membership(group, owner, :owner)

      assert {:ok, event} = Events.create_event(event_attrs(), scope: scope(owner, group))
      assert event.group_id == group.id
      assert event.author_id == owner.id
      assert event.status == :published

      assert {:ok, [publication]} =
               Ash.read(
                 EventPublication,
                 authorize?: false,
                 domain: Wik.Events,
                 load: [:event],
                 scope: scope(owner, group)
               )

      assert publication.event_id == event.id
      assert publication.publication_type == :origin
      assert publication.target_group_id == group.id
    end

    test "preserves the configured provenance policy" do
      owner = generate(user())
      group = generate(group(author: owner))
      add_membership(group, owner, :owner)

      attrs = event_attrs(provenance_policy: :hidden)

      assert {:ok, event} = Events.create_event(attrs, scope: scope(owner, group))
      assert event.provenance_policy == :hidden
    end

    test "allows all-day events to preserve an end time" do
      owner = generate(user())
      group = generate(group(author: owner))
      add_membership(group, owner, :owner)

      attrs =
        event_attrs(
          all_day: true,
          ends_on: "2026-05-15",
          starts_on: "2026-05-15"
        )

      assert {:ok, event} = Events.create_event(attrs, scope: scope(owner, group))
      assert event.all_day
      assert event.ends_at == ~U[2026-05-15 23:59:59Z]
    end
  end

  describe "relay_event_to_group/3" do
    test "blocks relay when the event is internal only" do
      actor = generate(user())
      origin_group = generate(group(author: actor))
      target_group = generate(group())

      add_membership(origin_group, actor, :owner)
      add_membership(target_group, actor, :owner)

      {:ok, event} =
        Events.create_event(event_attrs(relay_policy: :internal_only),
          scope: scope(actor, origin_group)
        )

      assert {:error, _error} =
               Events.relay_event_to_group(event, target_group, scope: scope(actor, origin_group))
    end

    test "allows admins to relay when the policy is admins only" do
      admin = generate(user())
      origin_owner = generate(user())
      origin_group = generate(group())
      target_group = generate(group(author: admin))

      add_membership(origin_group, origin_owner, :owner)
      add_membership(origin_group, admin, :admin)
      add_membership(target_group, admin, :owner)
      grant_active_telegram_access(origin_group, admin)

      {:ok, event} =
        Events.create_event(
          event_attrs(relay_policy: :admins_only_groups),
          scope: scope(origin_owner, origin_group)
        )

      assert {:ok, publication} =
               Events.relay_event_to_group(event, target_group, scope: scope(admin, origin_group))

      assert publication.publication_type == :relay
      assert publication.target_group_id == target_group.id
    end

    test "blocks members from relaying when the policy is admins only" do
      member = generate(user())
      origin_owner = generate(user())
      origin_group = generate(group(author: origin_owner))
      target_group = generate(group(author: member))

      add_membership(origin_group, origin_owner, :owner)
      add_membership(origin_group, member, :member)
      add_membership(target_group, member, :owner)
      grant_active_telegram_access(origin_group, member)

      {:ok, event} =
        Events.create_event(
          event_attrs(relay_policy: :admins_only_groups),
          scope: scope(origin_owner, origin_group)
        )

      assert {:error, _error} =
               Events.relay_event_to_group(event, target_group,
                 scope: scope(member, origin_group)
               )
    end

    test "allows members to relay when the policy allows members" do
      member = generate(user())
      origin_owner = generate(user())
      origin_group = generate(group(author: origin_owner))
      target_group = generate(group(author: member))

      add_membership(origin_group, origin_owner, :owner)
      add_membership(origin_group, member, :member)
      add_membership(target_group, member, :owner)
      grant_active_telegram_access(origin_group, member)

      {:ok, event} =
        Events.create_event(
          event_attrs(relay_policy: :members_to_groups),
          scope: scope(origin_owner, origin_group)
        )

      assert {:ok, publication} =
               Events.relay_event_to_group(event, target_group,
                 scope: scope(member, origin_group)
               )

      assert publication.publication_type == :relay
      assert publication.target_group_id == target_group.id
    end

    test "rejects duplicate relay into the same target group" do
      actor = generate(user())
      origin_group = generate(group(author: actor))
      target_group = generate(group(author: actor))

      add_membership(origin_group, actor, :owner)
      add_membership(target_group, actor, :owner)

      {:ok, event} =
        Events.create_event(
          event_attrs(relay_policy: :admins_only_groups),
          scope: scope(actor, origin_group)
        )

      assert {:ok, _publication} =
               Events.relay_event_to_group(event, target_group, scope: scope(actor, origin_group))

      assert {:error, _error} =
               Events.relay_event_to_group(event, target_group, scope: scope(actor, origin_group))
    end
  end

  describe "list_relay_target_groups/2" do
    test "excludes the origin group and groups where the event is already published" do
      actor = generate(user())
      origin_group = generate(group(author: actor))
      first_target_group = generate(group(author: actor))
      second_target_group = generate(group(author: actor))

      add_membership(origin_group, actor, :owner)
      add_membership(first_target_group, actor, :owner)
      add_membership(second_target_group, actor, :owner)

      {:ok, event} =
        Events.create_event(
          event_attrs(relay_policy: :admins_only_groups),
          scope: scope(actor, origin_group)
        )

      assert {:ok, _publication} =
               Events.relay_event_to_group(event, first_target_group,
                 scope: scope(actor, origin_group)
               )

      assert {:ok, [group]} = Events.list_relay_target_groups(event, scope(actor, origin_group))
      assert group.id == second_target_group.id
    end

    test "returns no targets for internal-only events" do
      actor = generate(user())
      origin_group = generate(group(author: actor))
      target_group = generate(group(author: actor))

      add_membership(origin_group, actor, :owner)
      add_membership(target_group, actor, :owner)

      {:ok, event} =
        Events.create_event(
          event_attrs(relay_policy: :internal_only),
          scope: scope(actor, origin_group)
        )

      assert {:ok, []} = Events.list_relay_target_groups(event, scope(actor, origin_group))
    end

    test "allows members to see target groups only when the policy allows members" do
      owner = generate(user())
      member = generate(user())
      origin_group = generate(group(author: owner))
      target_group = generate(group(author: member))

      add_membership(origin_group, owner, :owner)
      add_membership(origin_group, member, :member)
      add_membership(target_group, member, :owner)
      grant_active_telegram_access(origin_group, member)

      {:ok, admin_only_event} =
        Events.create_event(
          event_attrs(relay_policy: :admins_only_groups),
          scope: scope(owner, origin_group)
        )

      {:ok, members_event} =
        Events.create_event(
          event_attrs(
            relay_policy: :members_to_groups,
            starts_on: "2026-05-11",
            ends_on: "2026-05-11",
            title: "Members event"
          ),
          scope: scope(owner, origin_group)
        )

      assert {:ok, []} =
               Events.list_relay_target_groups(admin_only_event, scope(member, origin_group))

      assert {:ok, [group]} =
               Events.list_relay_target_groups(members_event, scope(member, origin_group))

      assert group.id == target_group.id
    end
  end

  describe "can_relay_event_to_any_group?/2" do
    test "returns false for internal-only events" do
      actor = generate(user())
      origin_group = generate(group(author: actor))
      target_group = generate(group(author: actor))

      add_membership(origin_group, actor, :owner)
      add_membership(target_group, actor, :owner)

      {:ok, event} =
        Events.create_event(
          event_attrs(relay_policy: :internal_only),
          scope: scope(actor, origin_group)
        )

      assert {:ok, false} =
               Events.can_relay_event_to_any_group?(event, scope(actor, origin_group))
    end

    test "returns false when no eligible targets remain" do
      actor = generate(user())
      origin_group = generate(group(author: actor))
      target_group = generate(group(author: actor))

      add_membership(origin_group, actor, :owner)
      add_membership(target_group, actor, :owner)

      {:ok, event} =
        Events.create_event(
          event_attrs(relay_policy: :admins_only_groups),
          scope: scope(actor, origin_group)
        )

      assert {:ok, _publication} =
               Events.relay_event_to_group(event, target_group, scope: scope(actor, origin_group))

      assert {:ok, false} =
               Events.can_relay_event_to_any_group?(event, scope(actor, origin_group))
    end

    test "returns true when at least one eligible target exists" do
      actor = generate(user())
      origin_group = generate(group(author: actor))
      target_group = generate(group(author: actor))

      add_membership(origin_group, actor, :owner)
      add_membership(target_group, actor, :owner)

      {:ok, event} =
        Events.create_event(
          event_attrs(relay_policy: :admins_only_groups),
          scope: scope(actor, origin_group)
        )

      assert {:ok, true} = Events.can_relay_event_to_any_group?(event, scope(actor, origin_group))
    end
  end

  describe "group event publications timeline load" do
    test "returns only upcoming publications visible in the current group ordered by start time" do
      actor = generate(user())
      group = generate(group(author: actor))

      add_membership(group, actor, :owner)

      {:ok, later_event} =
        Events.create_event(
          event_attrs(
            title: "Later",
            starts_on: "2026-05-20",
            starts_at_time: "18:00",
            ends_on: "2026-05-20",
            ends_at_time: "20:00"
          ),
          scope: scope(actor, group)
        )

      {:ok, earlier_event} =
        Events.create_event(
          event_attrs(
            title: "Earlier",
            starts_on: "2026-05-10",
            starts_at_time: "18:00",
            ends_on: "2026-05-10",
            ends_at_time: "20:00"
          ),
          scope: scope(actor, group)
        )

      {:ok, group} =
        Ash.load(group, [event_publications: timeline_query()], scope: scope(actor, group))

      assert Enum.map(group.event_publications, & &1.event_id) == [
               earlier_event.id,
               later_event.id
             ]
    end

    test "includes relayed events in the target group's timeline" do
      actor = generate(user())
      origin_group = generate(group(author: actor))
      target_group = generate(group(author: actor))

      add_membership(origin_group, actor, :owner)
      add_membership(target_group, actor, :owner)

      {:ok, event} =
        Events.create_event(
          event_attrs(relay_policy: :admins_only_groups),
          scope: scope(actor, origin_group)
        )

      {:ok, _publication} =
        Events.relay_event_to_group(event, target_group, scope: scope(actor, origin_group))

      {:ok, target_group} =
        Ash.load(
          target_group,
          [event_publications: timeline_query()],
          scope: scope(actor, target_group)
        )

      assert Enum.any?(
               target_group.event_publications,
               &(&1.event_id == event.id and &1.publication_type == :relay)
             )
    end

    test "keeps cancelled events visible in the group timeline" do
      actor = generate(user())
      group = generate(group(author: actor))

      add_membership(group, actor, :owner)

      {:ok, event} = Events.create_event(event_attrs(), scope: scope(actor, group))
      assert {:ok, _cancelled} = Wik.Events.Event.cancel(event, scope: scope(actor, group))

      {:ok, group} =
        Ash.load(group, [event_publications: timeline_query()], scope: scope(actor, group))

      assert [%{event: %{status: :cancelled}}] = group.event_publications
    end
  end

  defp add_membership(group, user, type) do
    {:ok, membership} =
      Ash.create(
        GroupUserRelation,
        %{group_id: group.id, type: type, user_id: user.id},
        authorize?: false,
        domain: Wik.Accounts
      )

    membership
  end

  defp event_attrs, do: event_attrs([])

  defp event_attrs(overrides) do
    %{
      all_day: false,
      description: "An event description",
      ends_at_time: "20:00",
      ends_on: "2026-05-10",
      location: "Community Hall, 123 Example Street",
      provenance_policy: :visible,
      relay_policy: :internal_only,
      starts_at_time: "18:00",
      starts_on: "2026-05-10",
      tz: "Etc/UTC",
      title: "Shared Dinner"
    }
    |> Map.merge(Enum.into(overrides, %{}))
  end

  defp scope(actor, tenant) do
    %Scope{actor: actor, tenant: tenant}
  end

  defp timeline_query do
    EventPublication
    |> Query.sort([{"event.starts_at", :asc}, {:inserted_at, :asc}])
    |> Query.load([:published_by, event: [:author, :group]])
  end
end
