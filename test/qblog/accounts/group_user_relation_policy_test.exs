defmodule Qblog.Accounts.GroupUserRelationPolicyTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Accounts.GroupUserRelation
  alias Qblog.Scope

  describe "superadmin" do
    test "can read any membership" do
      superadmin = generate(user(role: :superadmin))
      membership = membership_fixture(:member)

      assert Ash.can?({membership, :read}, scope(superadmin, membership.group_id))
    end

    test "can transfer ownership from an owner membership" do
      superadmin = generate(user(role: :superadmin))
      %{owner_membership: owner_membership} = transfer_fixture()

      assert Ash.can?(
               {owner_membership, :transfer_ownership},
               scope(superadmin, owner_membership.group_id)
             )
    end

    test "cannot transfer ownership from an admin membership" do
      superadmin = generate(user(role: :superadmin))
      membership = membership_fixture(:admin)

      refute Ash.can?({membership, :transfer_ownership}, scope(superadmin, membership.group_id))
    end

    test "cannot transfer ownership from a plain member membership" do
      superadmin = generate(user(role: :superadmin))
      membership = membership_fixture(:member)

      refute Ash.can?({membership, :transfer_ownership}, scope(superadmin, membership.group_id))
    end

    test "can update a non-owner membership type" do
      superadmin = generate(user(role: :superadmin))
      membership = membership_fixture(:member)

      assert Ash.can?({membership, :update}, scope(superadmin, membership.group_id))
    end

    test "can update their own membership type" do
      superadmin = generate(user(role: :superadmin))
      group = generate(group())
      membership = add_membership(group, superadmin, :member)

      assert Ash.can?({membership, :update}, scope(superadmin, group))
    end

    test "cannot update an owner membership type" do
      superadmin = generate(user(role: :superadmin))
      membership = membership_fixture(:owner)

      refute Ash.can?({membership, :update}, scope(superadmin, membership.group_id))
    end
  end

  describe "owner member" do
    test "can read memberships for their group" do
      %{owner: owner, owner_membership: owner_membership, member_membership: member_membership} =
        transfer_fixture()

      assert Ash.can?({owner_membership, :read}, scope(owner, owner_membership.group_id))
      assert Ash.can?({member_membership, :read}, scope(owner, member_membership.group_id))
    end

    test "can transfer ownership from their owner membership" do
      %{owner: owner, owner_membership: owner_membership} = transfer_fixture()

      assert Ash.can?(
               {owner_membership, :transfer_ownership},
               scope(owner, owner_membership.group_id)
             )
    end

    test "cannot transfer ownership from another row in the group" do
      %{owner: owner, member_membership: member_membership} = transfer_fixture()

      refute Ash.can?(
               {member_membership, :transfer_ownership},
               scope(owner, member_membership.group_id)
             )
    end

    test "can update a non-owner membership type in their group" do
      %{owner: owner, member_membership: member_membership} = transfer_fixture()

      assert Ash.can?(
               {member_membership, :update},
               scope(owner, member_membership.group_id)
             )
    end

    test "cannot update their owner membership type" do
      %{owner: owner, owner_membership: owner_membership} = transfer_fixture()

      refute Ash.can?(
               {owner_membership, :update},
               scope(owner, owner_membership.group_id)
             )
    end
  end

  describe "admin member" do
    test "can read memberships for their group" do
      admin = generate(user())
      group = generate(group())
      owner = generate(user())
      owner_membership = add_membership(group, owner, :owner)
      admin_membership = add_membership(group, admin, :admin)
      grant_active_telegram_access(group, admin)

      assert Ash.can?({owner_membership, :read}, scope(admin, group))
      assert Ash.can?({admin_membership, :read}, scope(admin, group))
    end

    test "cannot read memberships for a group they do not belong to" do
      admin = generate(user())
      member_group = generate(group())
      other_group = generate(group())

      add_membership(member_group, generate(user()), :owner)
      add_membership(member_group, admin, :admin)
      grant_active_telegram_access(member_group, admin)
      other_membership = add_membership(other_group, generate(user()), :member)

      refute Ash.can?({other_membership, :read}, scope(admin, member_group))
    end

    test "cannot list memberships for a group they do not belong to" do
      admin = generate(user())
      member_group = generate(group())
      other_group = generate(group())

      member_group_owner = add_membership(member_group, generate(user()), :owner)
      admin_membership = add_membership(member_group, admin, :admin)
      grant_active_telegram_access(member_group, admin)
      other_group_membership = add_membership(other_group, generate(user()), :member)

      assert {:ok, memberships} = Ash.read(GroupUserRelation, scope: scope(admin, member_group))

      assert Enum.any?(memberships, &(&1.id == member_group_owner.id))
      assert Enum.any?(memberships, &(&1.id == admin_membership.id))
      refute Enum.any?(memberships, &(&1.id == other_group_membership.id))
    end

    test "cannot transfer ownership from their admin membership" do
      admin = generate(user())
      group = generate(group())
      add_membership(group, generate(user()), :owner)
      admin_membership = add_membership(group, admin, :admin)

      refute Ash.can?({admin_membership, :transfer_ownership}, scope(admin, group))
    end

    test "cannot update another membership type in the group" do
      admin = generate(user())
      group = generate(group())
      add_membership(group, generate(user()), :owner)
      member_membership = add_membership(group, generate(user()), :member)
      add_membership(group, admin, :admin)

      refute Ash.can?({member_membership, :update}, scope(admin, group))
    end

    test "cannot update their own membership type" do
      admin = generate(user())
      group = generate(group())
      add_membership(group, generate(user()), :owner)
      admin_membership = add_membership(group, admin, :admin)

      refute Ash.can?({admin_membership, :update}, scope(admin, group))
    end
  end

  describe "plain member" do
    test "can read memberships for their group" do
      member = generate(user())
      group = generate(group())
      owner_membership = add_membership(group, generate(user()), :owner)
      member_membership = add_membership(group, member, :member)
      grant_active_telegram_access(group, member)

      assert Ash.can?({owner_membership, :read}, scope(member, group))
      assert Ash.can?({member_membership, :read}, scope(member, group))
    end

    test "cannot read memberships for a group they do not belong to" do
      member = generate(user())
      member_group = generate(group())
      other_group = generate(group())

      add_membership(member_group, generate(user()), :owner)
      add_membership(member_group, member, :member)
      grant_active_telegram_access(member_group, member)
      other_membership = add_membership(other_group, generate(user()), :member)

      refute Ash.can?({other_membership, :read}, scope(member, member_group))
    end

    test "cannot list memberships for a group they do not belong to" do
      member = generate(user())
      member_group = generate(group())
      other_group = generate(group())

      member_group_owner = add_membership(member_group, generate(user()), :owner)
      member_membership = add_membership(member_group, member, :member)
      grant_active_telegram_access(member_group, member)
      other_group_membership = add_membership(other_group, generate(user()), :member)

      assert {:ok, memberships} = Ash.read(GroupUserRelation, scope: scope(member, member_group))

      assert Enum.any?(memberships, &(&1.id == member_group_owner.id))
      assert Enum.any?(memberships, &(&1.id == member_membership.id))
      refute Enum.any?(memberships, &(&1.id == other_group_membership.id))
    end

    test "cannot transfer ownership from their member membership" do
      member = generate(user())
      group = generate(group())
      add_membership(group, generate(user()), :owner)
      member_membership = add_membership(group, member, :member)

      refute Ash.can?({member_membership, :transfer_ownership}, scope(member, group))
    end

    test "cannot update another membership type in the group" do
      member = generate(user())
      group = generate(group())
      add_membership(group, generate(user()), :owner)
      other_membership = add_membership(group, generate(user()), :member)
      add_membership(group, member, :member)

      refute Ash.can?({other_membership, :update}, scope(member, group))
    end

    test "cannot update their own membership type" do
      member = generate(user())
      group = generate(group())
      add_membership(group, generate(user()), :owner)
      member_membership = add_membership(group, member, :member)

      refute Ash.can?({member_membership, :update}, scope(member, group))
    end
  end

  describe "outsider" do
    test "cannot read memberships for a group they do not belong to" do
      outsider = generate(user())
      membership = membership_fixture(:member)

      refute Ash.can?({membership, :read}, scope(outsider, membership.group_id))
    end

    test "cannot transfer ownership from another group's owner membership" do
      outsider = generate(user())
      %{owner_membership: owner_membership} = transfer_fixture()

      refute Ash.can?(
               {owner_membership, :transfer_ownership},
               scope(outsider, owner_membership.group_id)
             )
    end

    test "cannot update another group's membership type" do
      outsider = generate(user())
      membership = membership_fixture(:member)

      refute Ash.can?({membership, :update}, scope(outsider, membership.group_id))
    end
  end

  describe "update action" do
    test "owner can update a member membership to admin" do
      %{group: group, owner: owner, member_membership: member_membership} = transfer_fixture()

      assert {:ok, updated_membership} =
               Ash.update(
                 member_membership,
                 %{type: :admin},
                 action: :update,
                 scope: scope(owner, group)
               )

      assert updated_membership.type == :admin
    end

    test "cannot update an owner membership type" do
      %{group: group, owner: owner, owner_membership: owner_membership} = transfer_fixture()

      assert {:error, _error} =
               Ash.update(
                 owner_membership,
                 %{type: :admin},
                 action: :update,
                 scope: scope(owner, group)
               )
    end
  end

  describe "transfer_ownership action" do
    test "demotes the current owner to admin and promotes the target membership to owner" do
      %{
        group: group,
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
                 scope: scope(owner, group)
               )

      {:ok, owner_membership_after} =
        Ash.get(GroupUserRelation, owner_membership.id, authorize?: false, domain: Qblog.Accounts)

      {:ok, member_membership_after} =
        Ash.get(GroupUserRelation, member_membership.id,
          authorize?: false,
          domain: Qblog.Accounts
        )

      assert owner_membership_after.type == :admin
      assert member_membership_after.type == :owner
    end

    test "fails when the target membership belongs to another group" do
      %{group: group, owner: owner, owner_membership: owner_membership} = transfer_fixture()
      other_group = generate(group())
      other_member = add_membership(other_group, generate(user()), :member)

      assert {:error, _error} =
               Ash.update(
                 owner_membership,
                 %{target_membership_id: other_member.id},
                 action: :transfer_ownership,
                 scope: scope(owner, group)
               )
    end

    test "no-ops when the target membership is the same membership" do
      %{group: group, owner: owner, owner_membership: owner_membership} = transfer_fixture()

      assert {:ok, _updated_membership} =
               Ash.update(
                 owner_membership,
                 %{target_membership_id: owner_membership.id},
                 action: :transfer_ownership,
                 scope: scope(owner, group)
               )

      {:ok, owner_membership_after} =
        Ash.get(GroupUserRelation, owner_membership.id, authorize?: false, domain: Qblog.Accounts)

      assert owner_membership_after.type == :owner
    end
  end

  defp transfer_fixture do
    group = generate(group())
    owner = generate(user())
    member = generate(user())

    owner_membership = add_membership(group, owner, :owner)
    member_membership = add_membership(group, member, :member)

    %{
      group: group,
      member: member,
      member_membership: member_membership,
      owner: owner,
      owner_membership: owner_membership
    }
  end

  defp membership_fixture(type) do
    group = generate(group())
    user = generate(user())

    add_membership(group, user, type)
  end

  defp add_membership(group, user, type) do
    {:ok, membership} =
      Ash.create(
        GroupUserRelation,
        %{
          group_id: group.id,
          type: type,
          user_id: user.id
        },
        authorize?: false,
        domain: Qblog.Accounts
      )

    membership
  end

  defp scope(actor, tenant) do
    %Scope{actor: actor, tenant: tenant}
  end
end
