defmodule Wik.Accounts.GroupPolicyTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.Group
  alias Wik.Accounts.GroupUserRelation
  alias Wik.Scope

  describe "superadmin" do
    test "can read any group" do
      superadmin = generate(user(role: :superadmin))
      group = generate(group())

      assert Ash.can?({group, :read}, scope(superadmin, group))
    end

    test "can create a group" do
      superadmin = generate(user(role: :superadmin))
      group = generate(group())

      assert Ash.can?({Group, :create}, scope(superadmin, group))
    end

    test "can update any group" do
      superadmin = generate(user(role: :superadmin))
      group = generate(group())

      assert Ash.can?({group, :update}, scope(superadmin, group))
    end

    test "can destroy any group" do
      superadmin = generate(user(role: :superadmin))
      group = generate(group())

      assert Ash.can?({group, :destroy}, scope(superadmin, group))
    end
  end

  describe "owner member" do
    test "can read their group" do
      owner = generate(user())
      group = generate(group(author: owner))
      add_membership(group, owner, :owner)

      assert Ash.can?({group, :read}, scope(owner, group))
    end

    test "can create a group" do
      owner = generate(user())
      current_group = generate(group(author: owner))
      add_membership(current_group, owner, :owner)

      assert Ash.can?({Group, :create}, scope(owner, current_group))
    end

    test "can update their group" do
      owner = generate(user())
      group = generate(group(author: owner))
      add_membership(group, owner, :owner)

      assert Ash.can?({group, :update}, scope(owner, group))
    end

    test "cannot destroy their group" do
      owner = generate(user())
      group = generate(group(author: owner))
      add_membership(group, owner, :owner)

      refute Ash.can?({group, :destroy}, scope(owner, group))
    end
  end

  describe "admin member" do
    test "can read their group" do
      admin = generate(user())
      group = generate(group())
      add_membership(group, admin, :admin)
      grant_active_telegram_access(group, admin)

      assert Ash.can?({group, :read}, scope(admin, group))
    end

    test "can create a group" do
      admin = generate(user())
      current_group = generate(group())
      add_membership(current_group, admin, :admin)
      grant_active_telegram_access(current_group, admin)

      assert Ash.can?({Group, :create}, scope(admin, current_group))
    end

    test "can update their group" do
      admin = generate(user())
      group = generate(group())
      add_membership(group, admin, :admin)
      grant_active_telegram_access(group, admin)

      assert Ash.can?({group, :update}, scope(admin, group))
    end

    test "cannot read their group without an active grant" do
      admin = generate(user())
      group = generate(group())
      add_membership(group, admin, :admin)

      refute Ash.can?({group, :read}, scope(admin, group))
    end

    test "cannot update their group without an active grant" do
      admin = generate(user())
      group = generate(group())
      add_membership(group, admin, :admin)

      refute Ash.can?({group, :update}, scope(admin, group))
    end

    test "cannot read a group they are not a member of" do
      admin = generate(user())
      member_group = generate(group())
      other_group = generate(group())

      add_membership(member_group, admin, :admin)
      grant_active_telegram_access(member_group, admin)

      refute Ash.can?({other_group, :read}, scope(admin, member_group))
    end

    test "cannot update a group they are not a member of" do
      admin = generate(user())
      member_group = generate(group())
      other_group = generate(group())

      add_membership(member_group, admin, :admin)
      grant_active_telegram_access(member_group, admin)

      refute Ash.can?({other_group, :update}, scope(admin, member_group))
    end

    test "cannot destroy a group they are not a member of" do
      admin = generate(user())
      member_group = generate(group())
      other_group = generate(group())

      add_membership(member_group, admin, :admin)
      grant_active_telegram_access(member_group, admin)

      refute Ash.can?({other_group, :destroy}, scope(admin, member_group))
    end

    test "cannot list groups they are not a member of" do
      admin = generate(user())
      member_group = generate(group())
      other_group = generate(group())

      add_membership(member_group, admin, :admin)
      grant_active_telegram_access(member_group, admin)

      assert {:ok, groups} = Wik.Accounts.list_groups(scope: scope(admin, member_group))
      assert Enum.any?(groups, &(&1.id == member_group.id))
      refute Enum.any?(groups, &(&1.id == other_group.id))
    end

    test "cannot destroy their group" do
      admin = generate(user())
      group = generate(group())
      add_membership(group, admin, :admin)
      grant_active_telegram_access(group, admin)

      refute Ash.can?({group, :destroy}, scope(admin, group))
    end
  end

  describe "plain member" do
    test "can read their group" do
      member = generate(user())
      group = generate(group())
      add_membership(group, member, :member)
      grant_active_telegram_access(group, member)

      assert Ash.can?({group, :read}, scope(member, group))
    end

    test "cannot read their group without an active grant" do
      member = generate(user())
      group = generate(group())
      add_membership(group, member, :member)

      refute Ash.can?({group, :read}, scope(member, group))
    end

    test "can create a group once they belong to a group" do
      member = generate(user())
      current_group = generate(group())
      add_membership(current_group, member, :member)
      grant_active_telegram_access(current_group, member)

      assert Ash.can?({Group, :create}, scope(member, current_group))
    end

    test "cannot update their group" do
      member = generate(user())
      group = generate(group())
      add_membership(group, member, :member)
      grant_active_telegram_access(group, member)

      refute Ash.can?({group, :update}, scope(member, group))
    end

    test "cannot read a group they are not a member of" do
      member = generate(user())
      member_group = generate(group())
      other_group = generate(group())

      add_membership(member_group, member, :member)
      grant_active_telegram_access(member_group, member)

      refute Ash.can?({other_group, :read}, scope(member, member_group))
    end

    test "cannot update a group they are not a member of" do
      member = generate(user())
      member_group = generate(group())
      other_group = generate(group())

      add_membership(member_group, member, :member)
      grant_active_telegram_access(member_group, member)

      refute Ash.can?({other_group, :update}, scope(member, member_group))
    end

    test "cannot destroy a group they are not a member of" do
      member = generate(user())
      member_group = generate(group())
      other_group = generate(group())

      add_membership(member_group, member, :member)
      grant_active_telegram_access(member_group, member)

      refute Ash.can?({other_group, :destroy}, scope(member, member_group))
    end

    test "cannot list groups they are not a member of" do
      member = generate(user())
      member_group = generate(group())
      other_group = generate(group())

      add_membership(member_group, member, :member)
      grant_active_telegram_access(member_group, member)

      assert {:ok, groups} = Wik.Accounts.list_groups(scope: scope(member, member_group))
      assert Enum.any?(groups, &(&1.id == member_group.id))
      refute Enum.any?(groups, &(&1.id == other_group.id))
    end

    test "cannot destroy their group" do
      member = generate(user())
      group = generate(group())
      add_membership(group, member, :member)
      grant_active_telegram_access(group, member)

      refute Ash.can?({group, :destroy}, scope(member, group))
    end
  end

  describe "outsider" do
    test "cannot read a group they are not a member of" do
      outsider = generate(user())
      group = generate(group())

      refute Ash.can?({group, :read}, scope(outsider, group))
    end

    test "cannot update a group they are not a member of" do
      outsider = generate(user())
      group = generate(group())

      refute Ash.can?({group, :update}, scope(outsider, group))
    end

    test "cannot destroy a group they are not a member of" do
      outsider = generate(user())
      group = generate(group())

      refute Ash.can?({group, :destroy}, scope(outsider, group))
    end
  end

  describe "user with no memberships" do
    test "cannot create a group" do
      user = generate(user())

      refute Ash.can?({Group, :create}, scope(user))
    end
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
        domain: Wik.Accounts
      )

    membership
  end

  defp scope(actor, tenant \\ nil) do
    %Scope{actor: actor, tenant: tenant}
  end
end
