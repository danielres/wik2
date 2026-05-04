defmodule Wik.EventsTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

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
          ends_at: ~U[2026-05-10 20:00:00Z]
        )

      assert {:ok, event} = Events.create_event(attrs, scope: scope(owner, group))
      assert event.all_day
      assert event.ends_at == ~U[2026-05-10 20:00:00Z]
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

  defp event_attrs(overrides \\ []) do
    starts_at = ~U[2026-05-10 18:00:00Z]
    ends_at = ~U[2026-05-10 20:00:00Z]

    %{
      all_day: false,
      description: "An event description",
      ends_at: ends_at,
      location_name: "Community Hall",
      location_text: "123 Example Street",
      provenance_policy: :visible,
      relay_policy: :internal_only,
      starts_at: starts_at,
      title: "Shared Dinner"
    }
    |> Map.merge(Enum.into(overrides, %{}))
  end

  defp scope(actor, tenant) do
    %Scope{actor: actor, tenant: tenant}
  end
end
