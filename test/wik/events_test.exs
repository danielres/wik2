defmodule Wik.EventsTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Ash.Query
  alias Wik.Accounts.Membership
  alias Wik.Events
  alias Wik.Events.Event
  alias Wik.Events.EventParticipation
  alias Wik.Events.EventPublication
  alias Wik.Events.ExternalCalendarSubscription
  alias Wik.Events.ExternalEvent
  alias Wik.Repo
  alias Wik.Scope

  describe "create/2" do
    test "creates the event and origin publication for an owner" do
      owner = generate(user())
      space = generate(space(author: owner))
      add_membership(space, owner, :owner)

      assert {:ok, event} =
               Ash.create(Event, event_attrs(), action: :create, scope: scope(owner, space))

      assert event.space_id == space.id
      assert event.author_id == owner.id
      assert event.status == :published

      assert {:ok, [publication]} =
               Ash.read(
                 EventPublication,
                 authorize?: false,
                 load: [:event],
                 scope: scope(owner, space)
               )

      assert publication.event_id == event.id
      assert publication.publication_type == :origin
      assert publication.target_space_id == space.id
    end

    test "allows all-day events to preserve an end time" do
      owner = generate(user())
      space = generate(space(author: owner))
      add_membership(space, owner, :owner)

      attrs =
        event_attrs(
          all_day: true,
          ends_on: "2026-05-15",
          starts_on: "2026-05-15"
        )

      assert {:ok, event} = Ash.create(Event, attrs, action: :create, scope: scope(owner, space))
      assert event.all_day
      assert event.ends_at == ~U[2026-05-15 23:59:59Z]
    end
  end

  describe "relay_to_space/3" do
    test "blocks relay when the event is internal only" do
      actor = generate(user())
      origin_space = generate(space(author: actor))
      target_space = generate(space())

      add_membership(origin_space, actor, :owner)
      add_membership(target_space, actor, :owner)

      {:ok, event} =
        Ash.create(Event, event_attrs(relay_policy: :internal_only),
          action: :create,
          scope: scope(actor, origin_space)
        )

      assert {:error, _error} =
               Events.relay_to_space(event, target_space, scope: scope(actor, origin_space))
    end

    test "allows admins to relay when the policy is admins only" do
      admin = generate(user())
      origin_owner = generate(user())
      origin_space = generate(space())
      target_space = generate(space(author: admin))

      add_membership(origin_space, origin_owner, :owner)
      add_membership(origin_space, admin, :admin)
      add_membership(target_space, admin, :owner)
      grant_active_telegram_access(origin_space, admin)

      {:ok, event} =
        Ash.create(
          Event,
          event_attrs(relay_policy: :admins_only_spaces),
          action: :create,
          scope: scope(origin_owner, origin_space)
        )

      assert {:ok, publication} =
               Events.relay_to_space(event, target_space, scope: scope(admin, origin_space))

      assert publication.publication_type == :relay
      assert publication.target_space_id == target_space.id
    end

    test "blocks members from relaying when the policy is admins only" do
      member = generate(user())
      origin_owner = generate(user())
      origin_space = generate(space(author: origin_owner))
      target_space = generate(space(author: member))

      add_membership(origin_space, origin_owner, :owner)
      add_membership(origin_space, member, :member)
      add_membership(target_space, member, :owner)
      grant_active_telegram_access(origin_space, member)

      {:ok, event} =
        Ash.create(
          Event,
          event_attrs(relay_policy: :admins_only_spaces),
          action: :create,
          scope: scope(origin_owner, origin_space)
        )

      assert {:error, _error} =
               Events.relay_to_space(event, target_space, scope: scope(member, origin_space))
    end

    test "allows members to relay when the policy allows members" do
      member = generate(user())
      origin_owner = generate(user())
      origin_space = generate(space(author: origin_owner))
      target_space = generate(space(author: member))

      add_membership(origin_space, origin_owner, :owner)
      add_membership(origin_space, member, :member)
      add_membership(target_space, member, :owner)
      grant_active_telegram_access(origin_space, member)

      {:ok, event} =
        Ash.create(
          Event,
          event_attrs(relay_policy: :members_to_spaces),
          action: :create,
          scope: scope(origin_owner, origin_space)
        )

      assert {:ok, publication} =
               Events.relay_to_space(event, target_space, scope: scope(member, origin_space))

      assert publication.publication_type == :relay
      assert publication.target_space_id == target_space.id
    end

    test "rejects duplicate relay into the same target space" do
      actor = generate(user())
      origin_space = generate(space(author: actor))
      target_space = generate(space(author: actor))

      add_membership(origin_space, actor, :owner)
      add_membership(target_space, actor, :owner)

      {:ok, event} =
        Ash.create(
          Event,
          event_attrs(relay_policy: :admins_only_spaces),
          action: :create,
          scope: scope(actor, origin_space)
        )

      assert {:ok, _publication} =
               Events.relay_to_space(event, target_space, scope: scope(actor, origin_space))

      assert {:error, _error} =
               Events.relay_to_space(event, target_space, scope: scope(actor, origin_space))
    end
  end

  describe "list_relay_target_spaces/2" do
    test "excludes the origin space and spaces where the event is already published" do
      actor = generate(user())
      origin_space = generate(space(author: actor))
      first_target_space = generate(space(author: actor))
      second_target_space = generate(space(author: actor))

      add_membership(origin_space, actor, :owner)
      add_membership(first_target_space, actor, :owner)
      add_membership(second_target_space, actor, :owner)

      {:ok, event} =
        Ash.create(
          Event,
          event_attrs(relay_policy: :admins_only_spaces),
          action: :create,
          scope: scope(actor, origin_space)
        )

      assert {:ok, _publication} =
               Events.relay_to_space(event, first_target_space, scope: scope(actor, origin_space))

      assert {:ok, [space]} = Events.list_relay_target_spaces(event, scope(actor, origin_space))
      assert space.id == second_target_space.id
    end

    test "returns no targets for internal-only events" do
      actor = generate(user())
      origin_space = generate(space(author: actor))
      target_space = generate(space(author: actor))

      add_membership(origin_space, actor, :owner)
      add_membership(target_space, actor, :owner)

      {:ok, event} =
        Ash.create(
          Event,
          event_attrs(relay_policy: :internal_only),
          action: :create,
          scope: scope(actor, origin_space)
        )

      assert {:ok, []} = Events.list_relay_target_spaces(event, scope(actor, origin_space))
    end

    test "allows members to see target spaces only when the policy allows members" do
      owner = generate(user())
      member = generate(user())
      origin_space = generate(space(author: owner))
      target_space = generate(space(author: member))

      add_membership(origin_space, owner, :owner)
      add_membership(origin_space, member, :member)
      add_membership(target_space, member, :owner)
      grant_active_telegram_access(origin_space, member)

      {:ok, admin_only_event} =
        Ash.create(
          Event,
          event_attrs(relay_policy: :admins_only_spaces),
          action: :create,
          scope: scope(owner, origin_space)
        )

      {:ok, members_event} =
        Ash.create(
          Event,
          event_attrs(
            relay_policy: :members_to_spaces,
            starts_on: "2026-05-11",
            ends_on: "2026-05-11",
            title: "Members event"
          ),
          action: :create,
          scope: scope(owner, origin_space)
        )

      assert {:ok, []} =
               Events.list_relay_target_spaces(admin_only_event, scope(member, origin_space))

      assert {:ok, [space]} =
               Events.list_relay_target_spaces(members_event, scope(member, origin_space))

      assert space.id == target_space.id
    end
  end

  describe "can_relay_event_to_any_space?/2" do
    test "returns false for internal-only events" do
      actor = generate(user())
      origin_space = generate(space(author: actor))
      target_space = generate(space(author: actor))

      add_membership(origin_space, actor, :owner)
      add_membership(target_space, actor, :owner)

      {:ok, event} =
        Ash.create(
          Event,
          event_attrs(relay_policy: :internal_only),
          action: :create,
          scope: scope(actor, origin_space)
        )

      assert {:ok, false} =
               Events.can_relay_event_to_any_space?(event, scope(actor, origin_space))
    end

    test "returns false when no eligible targets remain" do
      actor = generate(user())
      origin_space = generate(space(author: actor))
      target_space = generate(space(author: actor))

      add_membership(origin_space, actor, :owner)
      add_membership(target_space, actor, :owner)

      {:ok, event} =
        Ash.create(
          Event,
          event_attrs(relay_policy: :admins_only_spaces),
          action: :create,
          scope: scope(actor, origin_space)
        )

      assert {:ok, _publication} =
               Events.relay_to_space(event, target_space, scope: scope(actor, origin_space))

      assert {:ok, false} =
               Events.can_relay_event_to_any_space?(event, scope(actor, origin_space))
    end

    test "returns true when at least one eligible target exists" do
      actor = generate(user())
      origin_space = generate(space(author: actor))
      target_space = generate(space(author: actor))

      add_membership(origin_space, actor, :owner)
      add_membership(target_space, actor, :owner)

      {:ok, event} =
        Ash.create(
          Event,
          event_attrs(relay_policy: :admins_only_spaces),
          action: :create,
          scope: scope(actor, origin_space)
        )

      assert {:ok, true} = Events.can_relay_event_to_any_space?(event, scope(actor, origin_space))
    end
  end

  describe "space event publications timeline load" do
    test "returns only upcoming publications visible in the current space ordered by start time" do
      actor = generate(user())
      space = generate(space(author: actor))

      add_membership(space, actor, :owner)

      {:ok, later_event} =
        Ash.create(
          Event,
          event_attrs(
            title: "Later",
            starts_on: "2026-05-20",
            starts_at_time: "18:00",
            ends_on: "2026-05-20",
            ends_at_time: "20:00"
          ),
          action: :create,
          scope: scope(actor, space)
        )

      {:ok, earlier_event} =
        Ash.create(
          Event,
          event_attrs(
            title: "Earlier",
            starts_on: "2026-05-10",
            starts_at_time: "18:00",
            ends_on: "2026-05-10",
            ends_at_time: "20:00"
          ),
          action: :create,
          scope: scope(actor, space)
        )

      {:ok, space} =
        Ash.load(space, [event_publications: timeline_query()], scope: scope(actor, space))

      assert Enum.map(space.event_publications, & &1.event_id) == [
               earlier_event.id,
               later_event.id
             ]
    end

    test "includes relayed events in the target space's timeline" do
      actor = generate(user())
      origin_space = generate(space(author: actor))
      target_space = generate(space(author: actor))

      add_membership(origin_space, actor, :owner)
      add_membership(target_space, actor, :owner)

      {:ok, event} =
        Ash.create(
          Event,
          event_attrs(relay_policy: :admins_only_spaces),
          action: :create,
          scope: scope(actor, origin_space)
        )

      {:ok, _publication} =
        Events.relay_to_space(event, target_space, scope: scope(actor, origin_space))

      {:ok, target_space} =
        Ash.load(
          target_space,
          [event_publications: timeline_query()],
          scope: scope(actor, target_space)
        )

      assert Enum.any?(
               target_space.event_publications,
               &(&1.event_id == event.id and &1.publication_type == :relay)
             )
    end

    test "keeps cancelled events visible in the space timeline" do
      actor = generate(user())
      space = generate(space(author: actor))

      add_membership(space, actor, :owner)

      {:ok, event} = Ash.create(Event, event_attrs(), action: :create, scope: scope(actor, space))

      assert {:ok, _cancelled} =
               Ash.update(
                 event,
                 %{status: :cancelled},
                 action: :update,
                 scope: scope(actor, space)
               )

      {:ok, space} =
        Ash.load(space, [event_publications: timeline_query()], scope: scope(actor, space))

      assert [%{event: %{status: :cancelled}}] = space.event_publications
    end
  end

  describe "calendar feeds" do
    test "aggregate feed returns events visible across accessible spaces" do
      owner = generate(user())
      member = generate(user())
      first_space = generate(space(author: owner))
      second_space = generate(space(author: owner))

      add_membership(first_space, owner, :owner)
      add_membership(second_space, owner, :owner)
      add_membership(first_space, member, :member)
      add_membership(second_space, member, :member)
      grant_active_telegram_access(first_space, member)
      grant_active_telegram_access(second_space, member)

      {:ok, first_event} =
        Ash.create(
          Event,
          event_attrs(title: "First event"),
          action: :create,
          scope: scope(owner, first_space)
        )

      {:ok, second_event} =
        Ash.create(
          Event,
          event_attrs(
            starts_on: "2026-05-11",
            ends_on: "2026-05-11",
            title: "Second event"
          ),
          action: :create,
          scope: scope(owner, second_space)
        )

      assert {:ok, entries} = Events.list_aggregate_feed_events(member)
      assert Enum.map(entries, & &1.event.id) == [first_event.id, second_event.id]
    end

    test "aggregate feed excludes drafts and keeps cancelled events" do
      owner = generate(user())
      member = generate(user())
      space = generate(space(author: owner))

      add_membership(space, owner, :owner)
      add_membership(space, member, :member)
      grant_active_telegram_access(space, member)

      {:ok, cancelled_event} =
        Ash.create(
          Event,
          event_attrs(title: "Cancelled event"),
          action: :create,
          scope: scope(owner, space)
        )

      {:ok, draft_event} =
        Ash.create(
          Event,
          event_attrs(
            starts_on: "2026-05-11",
            ends_on: "2026-05-11",
            title: "Draft event"
          ),
          action: :create,
          scope: scope(owner, space)
        )

      assert {:ok, _cancelled} =
               Ash.update(
                 cancelled_event,
                 %{status: :cancelled},
                 action: :update,
                 scope: scope(owner, space)
               )

      assert {:ok, _draft} =
               Ash.update(
                 draft_event,
                 %{status: :draft},
                 action: :update,
                 scope: scope(owner, space)
               )

      assert {:ok, entries} = Events.list_aggregate_feed_events(member)
      assert Enum.map(entries, & &1.event.id) == [cancelled_event.id]
      assert hd(entries).event.status == :cancelled
    end

    test "aggregate feed excludes malformed scheduled events" do
      owner = generate(user())
      member = generate(user())
      space = generate(space(author: owner))

      add_membership(space, owner, :owner)
      add_membership(space, member, :member)
      grant_active_telegram_access(space, member)

      {:ok, event} =
        Ash.create(
          Event,
          event_attrs(title: "Malformed event"),
          action: :create,
          scope: scope(owner, space)
        )

      Repo.query!("UPDATE events SET starts_at = NULL, tz = NULL WHERE id = $1", [
        Ecto.UUID.dump!(event.id)
      ])

      assert {:ok, []} = Events.list_aggregate_feed_events(member)
    end

    test "aggregate feed includes external events with participation and excludes ghosts" do
      owner = generate(user())
      member = generate(user())
      space = generate(space(author: owner))

      add_membership(space, owner, :owner)
      membership = add_membership(space, member, :member)
      grant_active_telegram_access(space, member)

      external_event = external_event_fixture(space, owner)

      assert {:ok, []} = Events.list_aggregate_feed_events(member)

      assert {:ok, participation} =
               Events.record_external_interest(
                 external_event,
                 %{interest: 8, extra_info: "joining"},
                 scope: scope(member, space)
               )

      assert {:ok, [%{external_event: loaded_external_event, participations: participations}]} =
               Events.list_aggregate_feed_events(member)

      assert loaded_external_event.id == external_event.id

      assert [%EventParticipation{id: participation_id, membership: loaded_membership}] =
               participations

      assert participation_id == participation.id
      assert loaded_membership.id == membership.id
    end

    test "space feed returns only events visible in the selected space" do
      owner = generate(user())
      member = generate(user())
      first_space = generate(space(author: owner))
      second_space = generate(space(author: owner))

      add_membership(first_space, owner, :owner)
      add_membership(second_space, owner, :owner)
      add_membership(first_space, member, :member)
      add_membership(second_space, member, :member)
      grant_active_telegram_access(first_space, member)
      grant_active_telegram_access(second_space, member)

      {:ok, first_event} =
        Ash.create(
          Event,
          event_attrs(title: "First event"),
          action: :create,
          scope: scope(owner, first_space)
        )

      {:ok, _second_event} =
        Ash.create(
          Event,
          event_attrs(
            starts_on: "2026-05-11",
            ends_on: "2026-05-11",
            title: "Second event"
          ),
          action: :create,
          scope: scope(owner, second_space)
        )

      assert {:ok, %{events: events, space: space}} =
               Events.get_space_feed(member, first_space.id)

      assert space.id == first_space.id
      assert Enum.map(events, & &1.id) == [first_event.id]
    end

    test "space feed becomes unavailable after access is lost" do
      owner = generate(user())
      member = generate(user())
      space = generate(space(author: owner))

      add_membership(space, owner, :owner)
      add_membership(space, member, :member)
      %{grant: grant} = grant_active_telegram_access(space, member)

      {:ok, _event} =
        Ash.create(
          Event,
          event_attrs(title: "Shared dinner"),
          action: :create,
          scope: scope(owner, space)
        )

      assert {:ok, %{events: [_event], space: loaded_space}} =
               Events.get_space_feed(member, space.id)

      assert loaded_space.id == space.id

      Ash.update!(grant, %{status: :inactive},
        action: :update,
        authorize?: false
      )

      assert {:error, _error} = Events.get_space_feed(member, space.id)
    end
  end

  defp add_membership(space, user, type) do
    {:ok, membership} =
      Ash.create(
        Membership,
        %{space_id: space.id, type: type, user_id: user.id},
        authorize?: false
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
      relay_policy: :internal_only,
      starts_at_time: "18:00",
      starts_on: "2026-05-10",
      tz: "Etc/UTC",
      title: "Shared Dinner"
    }
    |> Map.merge(Enum.into(overrides, %{}))
  end

  defp external_event_fixture(space, owner) do
    {:ok, subscription} =
      ExternalCalendarSubscription.create(
        %{ics_url: "https://calendar.example.test/community.ics"},
        scope: scope(owner, space)
      )

    Repo.insert!(%ExternalEvent{
      id: Ash.UUIDv7.generate(),
      all_day: false,
      calendar_name: "Community calendar",
      description: "Imported from an external calendar",
      ends_at: ~U[2026-06-03 20:00:00.000000Z],
      event_url: nil,
      external_occurrence_key: "single",
      external_recurrence_id: nil,
      external_uid: "external-dinner",
      last_seen_at: DateTime.utc_now(),
      location: "Riverside Hall",
      space_id: space.id,
      starts_at: ~U[2026-06-03 18:00:00.000000Z],
      status: :published,
      subscription_id: subscription.id,
      title: "External dinner",
      tz: "Etc/UTC"
    })
  end

  defp scope(actor, tenant) do
    %Scope{actor: actor, tenant: tenant}
  end

  defp timeline_query do
    EventPublication
    |> Query.sort([{"event.starts_at", :asc}, {:inserted_at, :asc}])
    |> Query.load([:published_by, event: [:author, :space]])
  end
end
