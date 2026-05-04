defmodule Wik.Events.EventPolicyTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.GroupUserRelation
  alias Wik.Events
  alias Wik.Events.Event
  alias Wik.Scope

  describe "event access" do
    test "owner can read, create, update, and cancel their group's event" do
      owner = generate(user())
      group = generate(group(author: owner))

      add_membership(group, owner, :owner)

      {:ok, event} = Events.create_event(event_attrs(), scope: scope(owner, group))

      assert Ash.can?({event, :read}, scope(owner, group))
      assert Ash.can?({Event, :create}, scope(owner, group))
      assert Ash.can?({event, :update}, scope(owner, group))
      assert Ash.can?({event, :cancel}, scope(owner, group))
    end

    test "admin can read, create, update, and cancel their group's event" do
      owner = generate(user())
      admin = generate(user())
      group = generate(group(author: owner))

      add_membership(group, owner, :owner)
      add_membership(group, admin, :admin)
      grant_active_telegram_access(group, admin)

      {:ok, event} = Events.create_event(event_attrs(), scope: scope(owner, group))

      assert Ash.can?({event, :read}, scope(admin, group))
      assert Ash.can?({Event, :create}, scope(admin, group))
      assert Ash.can?({event, :update}, scope(admin, group))
      assert Ash.can?({event, :cancel}, scope(admin, group))
    end

    test "member can read but cannot create, update, or cancel" do
      owner = generate(user())
      member = generate(user())
      group = generate(group(author: owner))

      add_membership(group, owner, :owner)
      add_membership(group, member, :member)
      grant_active_telegram_access(group, member)

      {:ok, event} = Events.create_event(event_attrs(), scope: scope(owner, group))

      assert Ash.can?({event, :read}, scope(member, group))
      refute Ash.can?({Event, :create}, scope(member, group))
      refute Ash.can?({event, :update}, scope(member, group))
      refute Ash.can?({event, :cancel}, scope(member, group))
    end

    test "relay visibility allows target group members to read the event" do
      origin_owner = generate(user())
      relayer = generate(user())
      target_owner = generate(user())
      origin_group = generate(group(author: origin_owner))
      target_group = generate(group(author: target_owner))

      add_membership(origin_group, origin_owner, :owner)
      add_membership(origin_group, relayer, :member)
      add_membership(target_group, relayer, :owner)
      add_membership(target_group, target_owner, :owner)
      grant_active_telegram_access(origin_group, relayer)

      {:ok, event} =
        Events.create_event(
          event_attrs(relay_policy: :members_to_groups),
          scope: scope(origin_owner, origin_group)
        )

      assert {:ok, _publication} =
               Events.relay_event_to_group(event, target_group,
                 scope: scope(relayer, origin_group)
               )

      assert Ash.can?({event, :read}, scope(target_owner, target_group))
    end

    test "outsiders cannot read another group's event without a relay" do
      owner = generate(user())
      outsider = generate(user())
      group = generate(group(author: owner))

      add_membership(group, owner, :owner)

      {:ok, event} = Events.create_event(event_attrs(), scope: scope(owner, group))

      refute Ash.can?({event, :read}, scope(outsider, group))
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
