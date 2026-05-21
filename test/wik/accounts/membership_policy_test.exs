defmodule Wik.Accounts.MembershipPolicyTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.Membership
  alias Wik.Scope

  describe "superadmin" do
    test "can read any membership" do
      superadmin = generate(user(role: :superadmin))
      membership = membership_fixture(:member)

      assert Ash.can?({membership, :read}, scope(superadmin, membership.space_id))
    end

    test "can transfer ownership from an owner membership" do
      superadmin = generate(user(role: :superadmin))
      %{owner_membership: owner_membership} = transfer_fixture()

      assert Ash.can?(
               {owner_membership, :transfer_ownership},
               scope(superadmin, owner_membership.space_id)
             )
    end

    test "cannot transfer ownership from an admin membership" do
      superadmin = generate(user(role: :superadmin))
      membership = membership_fixture(:admin)

      refute Ash.can?({membership, :transfer_ownership}, scope(superadmin, membership.space_id))
    end

    test "cannot transfer ownership from a plain member membership" do
      superadmin = generate(user(role: :superadmin))
      membership = membership_fixture(:member)

      refute Ash.can?({membership, :transfer_ownership}, scope(superadmin, membership.space_id))
    end

    test "can update a non-owner membership type" do
      superadmin = generate(user(role: :superadmin))
      membership = membership_fixture(:member)

      assert Ash.can?(
               {membership, :update_membership_type},
               scope(superadmin, membership.space_id)
             )
    end

    test "can update their own membership type" do
      superadmin = generate(user(role: :superadmin))
      space = generate(space())
      membership = add_membership(space, superadmin, :member)

      assert Ash.can?({membership, :update_membership_type}, scope(superadmin, space))
    end

    test "cannot update an owner membership type" do
      superadmin = generate(user(role: :superadmin))
      membership = membership_fixture(:owner)

      refute Ash.can?(
               {membership, :update_membership_type},
               scope(superadmin, membership.space_id)
             )
    end

    test "publishes space and user topics when a membership type is updated" do
      superadmin = generate(user(role: :superadmin))
      membership = membership_fixture(:member)

      :ok =
        WikWeb.Endpoint.subscribe(Membership.space_pub_sub_topic(membership.space_id))

      :ok = WikWeb.Endpoint.subscribe(Membership.user_pub_sub_topic(membership.user_id))

      Ash.update!(
        membership,
        %{type: :admin},
        action: :update_membership_type,
        scope: scope(superadmin, membership.space_id),
        domain: Wik.Accounts
      )

      assert_receive %{topic: topic, payload: %{data: updated_membership}}, 1000
      assert topic == Membership.space_pub_sub_topic(membership.space_id)
      assert updated_membership.id == membership.id
      assert updated_membership.type == :admin

      assert_receive %{topic: topic, payload: %{data: updated_membership}}, 1000
      assert topic == Membership.user_pub_sub_topic(membership.user_id)
      assert updated_membership.id == membership.id
      assert updated_membership.type == :admin
    end
  end

  describe "owner member" do
    test "can read memberships for their space" do
      %{owner: owner, owner_membership: owner_membership, member_membership: member_membership} =
        transfer_fixture()

      assert Ash.can?({owner_membership, :read}, scope(owner, owner_membership.space_id))
      assert Ash.can?({member_membership, :read}, scope(owner, member_membership.space_id))
    end

    test "can transfer ownership from their owner membership" do
      %{owner: owner, owner_membership: owner_membership} = transfer_fixture()

      assert Ash.can?(
               {owner_membership, :transfer_ownership},
               scope(owner, owner_membership.space_id)
             )
    end

    test "cannot transfer ownership from another row in the space" do
      %{owner: owner, member_membership: member_membership} = transfer_fixture()

      refute Ash.can?(
               {member_membership, :transfer_ownership},
               scope(owner, member_membership.space_id)
             )
    end

    test "can update a non-owner membership type in their space" do
      %{owner: owner, member_membership: member_membership} = transfer_fixture()

      assert Ash.can?(
               {member_membership, :update_membership_type},
               scope(owner, member_membership.space_id)
             )
    end

    test "cannot update their owner membership type" do
      %{owner: owner, owner_membership: owner_membership} = transfer_fixture()

      refute Ash.can?(
               {owner_membership, :update_membership_type},
               scope(owner, owner_membership.space_id)
             )
    end
  end

  describe "admin member" do
    test "can read memberships for their space" do
      admin = generate(user())
      space = generate(space())
      owner = generate(user())
      owner_membership = add_membership(space, owner, :owner)
      admin_membership = add_membership(space, admin, :admin)
      grant_active_telegram_access(space, admin)

      assert Ash.can?({owner_membership, :read}, scope(admin, space))
      assert Ash.can?({admin_membership, :read}, scope(admin, space))
    end

    test "cannot read memberships for a space they do not belong to" do
      admin = generate(user())
      member_space = generate(space())
      other_space = generate(space())

      add_membership(member_space, generate(user()), :owner)
      add_membership(member_space, admin, :admin)
      grant_active_telegram_access(member_space, admin)
      other_membership = add_membership(other_space, generate(user()), :member)

      refute Ash.can?({other_membership, :read}, scope(admin, member_space))
    end

    test "cannot list memberships for a space they do not belong to" do
      admin = generate(user())
      member_space = generate(space())
      other_space = generate(space())

      member_space_owner = add_membership(member_space, generate(user()), :owner)
      admin_membership = add_membership(member_space, admin, :admin)
      grant_active_telegram_access(member_space, admin)
      other_space_membership = add_membership(other_space, generate(user()), :member)

      assert {:ok, memberships} = Ash.read(Membership, scope: scope(admin, member_space))

      assert Enum.any?(memberships, &(&1.id == member_space_owner.id))
      assert Enum.any?(memberships, &(&1.id == admin_membership.id))
      refute Enum.any?(memberships, &(&1.id == other_space_membership.id))
    end

    test "cannot transfer ownership from their admin membership" do
      admin = generate(user())
      space = generate(space())
      add_membership(space, generate(user()), :owner)
      admin_membership = add_membership(space, admin, :admin)

      refute Ash.can?({admin_membership, :transfer_ownership}, scope(admin, space))
    end

    test "cannot update another membership type in the space" do
      admin = generate(user())
      space = generate(space())
      add_membership(space, generate(user()), :owner)
      member_membership = add_membership(space, generate(user()), :member)
      add_membership(space, admin, :admin)

      refute Ash.can?({member_membership, :update_membership_type}, scope(admin, space))
    end

    test "cannot update their own membership type" do
      admin = generate(user())
      space = generate(space())
      add_membership(space, generate(user()), :owner)
      admin_membership = add_membership(space, admin, :admin)

      refute Ash.can?({admin_membership, :update_membership_type}, scope(admin, space))
    end
  end

  describe "plain member" do
    test "can read memberships for their space" do
      member = generate(user())
      space = generate(space())
      owner_membership = add_membership(space, generate(user()), :owner)
      member_membership = add_membership(space, member, :member)
      grant_active_telegram_access(space, member)

      assert Ash.can?({owner_membership, :read}, scope(member, space))
      assert Ash.can?({member_membership, :read}, scope(member, space))
    end

    test "cannot read memberships for a space they do not belong to" do
      member = generate(user())
      member_space = generate(space())
      other_space = generate(space())

      add_membership(member_space, generate(user()), :owner)
      add_membership(member_space, member, :member)
      grant_active_telegram_access(member_space, member)
      other_membership = add_membership(other_space, generate(user()), :member)

      refute Ash.can?({other_membership, :read}, scope(member, member_space))
    end

    test "cannot list memberships for a space they do not belong to" do
      member = generate(user())
      member_space = generate(space())
      other_space = generate(space())

      member_space_owner = add_membership(member_space, generate(user()), :owner)
      member_membership = add_membership(member_space, member, :member)
      grant_active_telegram_access(member_space, member)
      other_space_membership = add_membership(other_space, generate(user()), :member)

      assert {:ok, memberships} = Ash.read(Membership, scope: scope(member, member_space))

      assert Enum.any?(memberships, &(&1.id == member_space_owner.id))
      assert Enum.any?(memberships, &(&1.id == member_membership.id))
      refute Enum.any?(memberships, &(&1.id == other_space_membership.id))
    end

    test "cannot transfer ownership from their member membership" do
      member = generate(user())
      space = generate(space())
      add_membership(space, generate(user()), :owner)
      member_membership = add_membership(space, member, :member)

      refute Ash.can?({member_membership, :transfer_ownership}, scope(member, space))
    end

    test "cannot update another membership type in the space" do
      member = generate(user())
      space = generate(space())
      add_membership(space, generate(user()), :owner)
      other_membership = add_membership(space, generate(user()), :member)
      add_membership(space, member, :member)

      refute Ash.can?({other_membership, :update_membership_type}, scope(member, space))
    end

    test "cannot update their own membership type" do
      member = generate(user())
      space = generate(space())
      add_membership(space, generate(user()), :owner)
      member_membership = add_membership(space, member, :member)

      refute Ash.can?({member_membership, :update_membership_type}, scope(member, space))
    end
  end

  describe "outsider" do
    test "cannot read memberships for a space they do not belong to" do
      outsider = generate(user())
      membership = membership_fixture(:member)

      refute Ash.can?({membership, :read}, scope(outsider, membership.space_id))
    end

    test "cannot transfer ownership from another space's owner membership" do
      outsider = generate(user())
      %{owner_membership: owner_membership} = transfer_fixture()

      refute Ash.can?(
               {owner_membership, :transfer_ownership},
               scope(outsider, owner_membership.space_id)
             )
    end

    test "cannot update another space's membership type" do
      outsider = generate(user())
      membership = membership_fixture(:member)

      refute Ash.can?({membership, :update_membership_type}, scope(outsider, membership.space_id))
    end
  end

  describe "update_membership_type action" do
    test "owner can update a member membership to admin" do
      %{space: space, owner: owner, member_membership: member_membership} = transfer_fixture()

      assert {:ok, updated_membership} =
               Ash.update(
                 member_membership,
                 %{type: :admin},
                 action: :update_membership_type,
                 scope: scope(owner, space)
               )

      assert updated_membership.type == :admin
    end

    test "cannot update an owner membership type" do
      %{space: space, owner: owner, owner_membership: owner_membership} = transfer_fixture()

      assert {:error, _error} =
               Ash.update(
                 owner_membership,
                 %{type: :admin},
                 action: :update_membership_type,
                 scope: scope(owner, space)
               )
    end
  end

  describe "transfer_ownership action" do
    test "forbids promoting a membership to owner through update_membership_type" do
      %{
        space: space,
        owner: owner,
        member_membership: member_membership
      } =
        transfer_fixture()

      assert {:error, _error} =
               Ash.update(
                 member_membership,
                 %{type: :owner},
                 action: :update_membership_type,
                 scope: scope(owner, space)
               )
    end

    test "demotes the current owner to admin and promotes the target membership to owner" do
      %{
        space: space,
        owner: owner,
        owner_membership: owner_membership,
        member_membership: member_membership
      } =
        transfer_fixture()

      assert {:ok, _updated_membership} =
               Ash.update(
                 owner_membership,
                 %{target_membership_id: member_membership.id},
                 action: :transfer_ownership,
                 scope: scope(owner, space)
               )

      {:ok, owner_membership_after} =
        Ash.get(Membership, owner_membership.id, authorize?: false, domain: Wik.Accounts)

      {:ok, member_membership_after} =
        Ash.get(Membership, member_membership.id,
          authorize?: false,
          domain: Wik.Accounts
        )

      assert owner_membership_after.type == :admin
      assert member_membership_after.type == :owner
    end

    test "fails when the target membership belongs to another space" do
      %{space: space, owner: owner, owner_membership: owner_membership} = transfer_fixture()
      other_space = generate(space())
      other_member = add_membership(other_space, generate(user()), :member)

      assert {:error, _error} =
               Ash.update(
                 owner_membership,
                 %{target_membership_id: other_member.id},
                 action: :transfer_ownership,
                 scope: scope(owner, space)
               )
    end

    test "no-ops when the target membership is the same membership" do
      %{space: space, owner: owner, owner_membership: owner_membership} = transfer_fixture()

      assert {:ok, _updated_membership} =
               Ash.update(
                 owner_membership,
                 %{target_membership_id: owner_membership.id},
                 action: :transfer_ownership,
                 scope: scope(owner, space)
               )

      {:ok, owner_membership_after} =
        Ash.get(Membership, owner_membership.id, authorize?: false, domain: Wik.Accounts)

      assert owner_membership_after.type == :owner
    end
  end

  defp transfer_fixture do
    space = generate(space())
    owner = generate(user())
    member = generate(user())

    owner_membership = add_membership(space, owner, :owner)
    member_membership = add_membership(space, member, :member)

    %{
      space: space,
      member: member,
      member_membership: member_membership,
      owner: owner,
      owner_membership: owner_membership
    }
  end

  defp membership_fixture(type) do
    space = generate(space())
    user = generate(user())

    add_membership(space, user, type)
  end

  defp add_membership(space, user, type) do
    {:ok, membership} =
      Ash.create(
        Membership,
        %{
          space_id: space.id,
          type: type,
          user_id: user.id
        },
        authorize?: false,
        domain: Wik.Accounts
      )

    membership
  end

  defp scope(actor, tenant) do
    %Scope{actor: actor, tenant: tenant}
  end
end
