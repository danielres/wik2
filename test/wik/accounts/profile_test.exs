defmodule Wik.Accounts.ProfileTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.Membership
  alias Wik.Accounts.Profile
  alias Wik.Scope

  describe "create" do
    test "creates a profile for a membership" do
      membership = membership_fixture(:member)

      assert {:ok, profile} =
               Ash.create(
                 Profile,
                 %{membership_id: membership.id},
                 authorize?: false,
                 domain: Wik.Accounts
               )

      assert profile.membership_id == membership.id

      assert {:ok, membership_with_profile} =
               Ash.load(
                 membership,
                 :profile,
                 authorize?: false,
                 domain: Wik.Accounts
               )

      assert membership_with_profile.profile.id == profile.id
    end

    test "allows only one profile per membership" do
      membership = membership_fixture(:member)

      assert {:ok, _profile} =
               Ash.create(
                 Profile,
                 %{membership_id: membership.id},
                 authorize?: false,
                 domain: Wik.Accounts
               )

      assert {:error, _error} =
               Ash.create(
                 Profile,
                 %{membership_id: membership.id},
                 authorize?: false,
                 domain: Wik.Accounts
               )
    end
  end

  describe "read policy" do
    test "allows members of the same space to read a profile" do
      space = generate(space())
      profile_owner = generate(user())
      peer = generate(user())

      membership = add_membership(space, profile_owner, :member)
      add_membership(space, peer, :member)
      grant_active_telegram_access(space, peer)
      profile = create_profile(membership)

      assert Ash.can?({profile, :read}, scope(peer, space))
    end

    test "forbids users outside the space from reading a profile" do
      space = generate(space())
      outsider = generate(user())
      membership = add_membership(space, generate(user()), :member)
      profile = create_profile(membership)

      refute Ash.can?({profile, :read}, scope(outsider, space))
    end

    test "allows a superadmin to read any profile" do
      superadmin = generate(user(role: :superadmin))
      membership = membership_fixture(:member)
      profile = create_profile(membership)

      assert Ash.can?({profile, :read}, scope(superadmin, membership.space_id))
    end
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

  defp create_profile(membership) do
    {:ok, profile} =
      Ash.create(
        Profile,
        %{membership_id: membership.id},
        authorize?: false,
        domain: Wik.Accounts
      )

    profile
  end

  defp scope(actor, tenant) do
    %Scope{actor: actor, tenant: tenant}
  end
end
