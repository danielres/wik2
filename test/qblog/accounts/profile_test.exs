defmodule Qblog.Accounts.ProfileTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Accounts.GroupUserRelation
  alias Qblog.Accounts.Profile
  alias Qblog.Scope

  describe "create" do
    test "creates a profile for a membership" do
      membership = membership_fixture(:member)

      assert {:ok, profile} =
               Ash.create(
                 Profile,
                 %{group_user_relation_id: membership.id},
                 authorize?: false,
                 domain: Qblog.Accounts
               )

      assert profile.group_user_relation_id == membership.id

      assert {:ok, membership_with_profile} =
               Ash.load(
                 membership,
                 :profile,
                 authorize?: false,
                 domain: Qblog.Accounts
               )

      assert membership_with_profile.profile.id == profile.id
    end

    test "allows only one profile per membership" do
      membership = membership_fixture(:member)

      assert {:ok, _profile} =
               Ash.create(
                 Profile,
                 %{group_user_relation_id: membership.id},
                 authorize?: false,
                 domain: Qblog.Accounts
               )

      assert {:error, _error} =
               Ash.create(
                 Profile,
                 %{group_user_relation_id: membership.id},
                 authorize?: false,
                 domain: Qblog.Accounts
               )
    end
  end

  describe "read policy" do
    test "allows members of the same group to read a profile" do
      group = generate(group())
      profile_owner = generate(user())
      peer = generate(user())

      membership = add_membership(group, profile_owner, :member)
      add_membership(group, peer, :member)
      grant_active_telegram_access(group, peer)
      profile = create_profile(membership)

      assert Ash.can?({profile, :read}, scope(peer, group))
    end

    test "forbids users outside the group from reading a profile" do
      group = generate(group())
      outsider = generate(user())
      membership = add_membership(group, generate(user()), :member)
      profile = create_profile(membership)

      refute Ash.can?({profile, :read}, scope(outsider, group))
    end

    test "allows a superadmin to read any profile" do
      superadmin = generate(user(role: :superadmin))
      membership = membership_fixture(:member)
      profile = create_profile(membership)

      assert Ash.can?({profile, :read}, scope(superadmin, membership.group_id))
    end
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

  defp create_profile(membership) do
    {:ok, profile} =
      Ash.create(
        Profile,
        %{group_user_relation_id: membership.id},
        authorize?: false,
        domain: Qblog.Accounts
      )

    profile
  end

  defp scope(actor, tenant) do
    %Scope{actor: actor, tenant: tenant}
  end
end
