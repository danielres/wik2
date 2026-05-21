defmodule Wik.Accounts.SpacePolicyTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.Space
  alias Wik.Accounts.Membership
  alias Wik.Scope

  describe "superadmin" do
    test "can read any space" do
      superadmin = generate(user(role: :superadmin))
      space = generate(space())

      assert Ash.can?({space, :read}, scope(superadmin, space))
    end

    test "can create a space" do
      superadmin = generate(user(role: :superadmin))
      space = generate(space())

      assert Ash.can?({Space, :create}, scope(superadmin, space))
    end

    test "can update any space" do
      superadmin = generate(user(role: :superadmin))
      space = generate(space())

      assert Ash.can?({space, :update}, scope(superadmin, space))
    end

    test "can destroy any space" do
      superadmin = generate(user(role: :superadmin))
      space = generate(space())

      assert Ash.can?({space, :destroy}, scope(superadmin, space))
    end
  end

  describe "owner member" do
    test "can read their space" do
      owner = generate(user())
      space = generate(space(author: owner))
      add_membership(space, owner, :owner)

      assert Ash.can?({space, :read}, scope(owner, space))
    end

    test "can create a space" do
      owner = generate(user())
      current_space = generate(space(author: owner))
      add_membership(current_space, owner, :owner)

      assert Ash.can?({Space, :create}, scope(owner, current_space))
    end

    test "can update their space" do
      owner = generate(user())
      space = generate(space(author: owner))
      add_membership(space, owner, :owner)

      assert Ash.can?({space, :update}, scope(owner, space))
    end

    test "cannot destroy their space" do
      owner = generate(user())
      space = generate(space(author: owner))
      add_membership(space, owner, :owner)

      refute Ash.can?({space, :destroy}, scope(owner, space))
    end
  end

  describe "admin member" do
    test "can read their space" do
      admin = generate(user())
      space = generate(space())
      add_membership(space, admin, :admin)
      grant_active_telegram_access(space, admin)

      assert Ash.can?({space, :read}, scope(admin, space))
    end

    test "can create a space" do
      admin = generate(user())
      current_space = generate(space())
      add_membership(current_space, admin, :admin)
      grant_active_telegram_access(current_space, admin)

      assert Ash.can?({Space, :create}, scope(admin, current_space))
    end

    test "can update their space" do
      admin = generate(user())
      space = generate(space())
      add_membership(space, admin, :admin)
      grant_active_telegram_access(space, admin)

      assert Ash.can?({space, :update}, scope(admin, space))
    end

    test "cannot read their space without an active grant" do
      admin = generate(user())
      space = generate(space())
      add_membership(space, admin, :admin)

      refute Ash.can?({space, :read}, scope(admin, space))
    end

    test "cannot update their space without an active grant" do
      admin = generate(user())
      space = generate(space())
      add_membership(space, admin, :admin)

      refute Ash.can?({space, :update}, scope(admin, space))
    end

    test "cannot read a space they are not a member of" do
      admin = generate(user())
      member_space = generate(space())
      other_space = generate(space())

      add_membership(member_space, admin, :admin)
      grant_active_telegram_access(member_space, admin)

      refute Ash.can?({other_space, :read}, scope(admin, member_space))
    end

    test "cannot update a space they are not a member of" do
      admin = generate(user())
      member_space = generate(space())
      other_space = generate(space())

      add_membership(member_space, admin, :admin)
      grant_active_telegram_access(member_space, admin)

      refute Ash.can?({other_space, :update}, scope(admin, member_space))
    end

    test "cannot destroy a space they are not a member of" do
      admin = generate(user())
      member_space = generate(space())
      other_space = generate(space())

      add_membership(member_space, admin, :admin)
      grant_active_telegram_access(member_space, admin)

      refute Ash.can?({other_space, :destroy}, scope(admin, member_space))
    end

    test "cannot list spaces they are not a member of" do
      admin = generate(user())
      member_space = generate(space())
      other_space = generate(space())

      add_membership(member_space, admin, :admin)
      grant_active_telegram_access(member_space, admin)

      assert {:ok, spaces} = Wik.Accounts.list_spaces(scope: scope(admin, member_space))
      assert Enum.any?(spaces, &(&1.id == member_space.id))
      refute Enum.any?(spaces, &(&1.id == other_space.id))
    end

    test "cannot destroy their space" do
      admin = generate(user())
      space = generate(space())
      add_membership(space, admin, :admin)
      grant_active_telegram_access(space, admin)

      refute Ash.can?({space, :destroy}, scope(admin, space))
    end
  end

  describe "plain member" do
    test "can read their space" do
      member = generate(user())
      space = generate(space())
      add_membership(space, member, :member)
      grant_active_telegram_access(space, member)

      assert Ash.can?({space, :read}, scope(member, space))
    end

    test "cannot read their space without an active grant" do
      member = generate(user())
      space = generate(space())
      add_membership(space, member, :member)

      refute Ash.can?({space, :read}, scope(member, space))
    end

    test "can create a space once they belong to a space" do
      member = generate(user())
      current_space = generate(space())
      add_membership(current_space, member, :member)
      grant_active_telegram_access(current_space, member)

      assert Ash.can?({Space, :create}, scope(member, current_space))
    end

    test "cannot update their space" do
      member = generate(user())
      space = generate(space())
      add_membership(space, member, :member)
      grant_active_telegram_access(space, member)

      refute Ash.can?({space, :update}, scope(member, space))
    end

    test "cannot read a space they are not a member of" do
      member = generate(user())
      member_space = generate(space())
      other_space = generate(space())

      add_membership(member_space, member, :member)
      grant_active_telegram_access(member_space, member)

      refute Ash.can?({other_space, :read}, scope(member, member_space))
    end

    test "cannot update a space they are not a member of" do
      member = generate(user())
      member_space = generate(space())
      other_space = generate(space())

      add_membership(member_space, member, :member)
      grant_active_telegram_access(member_space, member)

      refute Ash.can?({other_space, :update}, scope(member, member_space))
    end

    test "cannot destroy a space they are not a member of" do
      member = generate(user())
      member_space = generate(space())
      other_space = generate(space())

      add_membership(member_space, member, :member)
      grant_active_telegram_access(member_space, member)

      refute Ash.can?({other_space, :destroy}, scope(member, member_space))
    end

    test "cannot list spaces they are not a member of" do
      member = generate(user())
      member_space = generate(space())
      other_space = generate(space())

      add_membership(member_space, member, :member)
      grant_active_telegram_access(member_space, member)

      assert {:ok, spaces} = Wik.Accounts.list_spaces(scope: scope(member, member_space))
      assert Enum.any?(spaces, &(&1.id == member_space.id))
      refute Enum.any?(spaces, &(&1.id == other_space.id))
    end

    test "cannot destroy their space" do
      member = generate(user())
      space = generate(space())
      add_membership(space, member, :member)
      grant_active_telegram_access(space, member)

      refute Ash.can?({space, :destroy}, scope(member, space))
    end
  end

  describe "outsider" do
    test "cannot read a space they are not a member of" do
      outsider = generate(user())
      space = generate(space())

      refute Ash.can?({space, :read}, scope(outsider, space))
    end

    test "cannot update a space they are not a member of" do
      outsider = generate(user())
      space = generate(space())

      refute Ash.can?({space, :update}, scope(outsider, space))
    end

    test "cannot destroy a space they are not a member of" do
      outsider = generate(user())
      space = generate(space())

      refute Ash.can?({space, :destroy}, scope(outsider, space))
    end
  end

  describe "user with no memberships" do
    test "cannot create a space" do
      user = generate(user())

      refute Ash.can?({Space, :create}, scope(user))
    end
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

  defp scope(actor, tenant \\ nil) do
    %Scope{actor: actor, tenant: tenant}
  end
end
