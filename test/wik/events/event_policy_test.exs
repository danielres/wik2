defmodule Wik.Events.EventPolicyTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.Membership
  alias Wik.Events
  alias Wik.Events.Event
  alias Wik.Scope

  describe "event access" do
    test "owner can read, create, and update their space's event" do
      owner = generate(user())
      space = generate(space(author: owner))

      add_membership(space, owner, :owner)

      {:ok, event} = Ash.create(Event, event_attrs(), action: :create, scope: scope(owner, space))

      assert Ash.can?({event, :read}, scope(owner, space))
      assert Ash.can?({Event, :create}, scope(owner, space))
      assert Ash.can?({event, :update}, scope(owner, space))
    end

    test "admin can read, create, and update their space's event" do
      owner = generate(user())
      admin = generate(user())
      space = generate(space(author: owner))

      add_membership(space, owner, :owner)
      add_membership(space, admin, :admin)
      grant_active_telegram_access(space, admin)

      {:ok, event} = Ash.create(Event, event_attrs(), action: :create, scope: scope(owner, space))

      assert Ash.can?({event, :read}, scope(admin, space))
      assert Ash.can?({Event, :create}, scope(admin, space))
      assert Ash.can?({event, :update}, scope(admin, space))
    end

    test "member can read but cannot create or update" do
      owner = generate(user())
      member = generate(user())
      space = generate(space(author: owner))

      add_membership(space, owner, :owner)
      add_membership(space, member, :member)
      grant_active_telegram_access(space, member)

      {:ok, event} = Ash.create(Event, event_attrs(), action: :create, scope: scope(owner, space))

      assert Ash.can?({event, :read}, scope(member, space))
      refute Ash.can?({Event, :create}, scope(member, space))
      refute Ash.can?({event, :update}, scope(member, space))
    end

    test "relay visibility allows target space members to read the event" do
      origin_owner = generate(user())
      relayer = generate(user())
      target_owner = generate(user())
      origin_space = generate(space(author: origin_owner))
      target_space = generate(space(author: target_owner))

      add_membership(origin_space, origin_owner, :owner)
      add_membership(origin_space, relayer, :member)
      add_membership(target_space, relayer, :owner)
      add_membership(target_space, target_owner, :owner)
      grant_active_telegram_access(origin_space, relayer)

      {:ok, event} =
        Ash.create(
          Event,
          event_attrs(relay_policy: :members_to_spaces),
          action: :create,
          scope: scope(origin_owner, origin_space)
        )

      assert {:ok, _publication} =
               Events.relay_to_space(event, target_space, scope: scope(relayer, origin_space))

      assert Ash.can?({event, :read}, scope(target_owner, target_space))
    end

    test "outsiders cannot read another space's event without a relay" do
      owner = generate(user())
      outsider = generate(user())
      space = generate(space(author: owner))

      add_membership(space, owner, :owner)

      {:ok, event} = Ash.create(Event, event_attrs(), action: :create, scope: scope(owner, space))

      refute Ash.can?({event, :read}, scope(outsider, space))
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

  defp event_attrs(overrides \\ []) do
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

  defp scope(actor, tenant) do
    %Scope{actor: actor, tenant: tenant}
  end
end
