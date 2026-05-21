defmodule Wik.Accounts.MembershipUsernameTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Access
  alias Wik.Accounts.Membership
  alias Wik.Scope

  describe "set_username action" do
    test "sets the username once for the membership owner" do
      space = generate(space())
      user = generate(user())
      membership = add_membership(space, user, :member)

      assert {:ok, updated_membership} =
               Ash.update(
                 membership,
                 %{username: "alice"},
                 action: :set_username,
                 scope: scope(user, space)
               )

      assert updated_membership.username == "alice"
    end

    test "rejects changing the username after it has been set" do
      space = generate(space())
      user = generate(user())
      membership = add_membership(space, user, :member)

      assert {:ok, membership} =
               Ash.update(
                 membership,
                 %{username: "alice"},
                 action: :set_username,
                 scope: scope(user, space)
               )

      assert {:error, _error} =
               Ash.update(
                 membership,
                 %{username: "bob"},
                 action: :set_username,
                 scope: scope(user, space)
               )
    end

    test "enforces uniqueness within a space" do
      space = generate(space())
      first_user = generate(user())
      second_user = generate(user())
      first_membership = add_membership(space, first_user, :member)
      second_membership = add_membership(space, second_user, :member)

      assert {:ok, _membership} =
               Ash.update(
                 first_membership,
                 %{username: "shared"},
                 action: :set_username,
                 scope: scope(first_user, space)
               )

      assert {:error, _error} =
               Ash.update(
                 second_membership,
                 %{username: "shared"},
                 action: :set_username,
                 scope: scope(second_user, space)
               )
    end

    test "rejects usernames that do not match the slug format" do
      space = generate(space())
      user = generate(user())
      membership = add_membership(space, user, :member)

      assert {:error, _error} =
               Ash.update(
                 membership,
                 %{username: "not valid"},
                 action: :set_username,
                 scope: scope(user, space)
               )
    end

    test "rejects usernames with underscores" do
      space = generate(space())
      user = generate(user())
      membership = add_membership(space, user, :member)

      assert {:error, _error} =
               Ash.update(
                 membership,
                 %{username: "not_valid"},
                 action: :set_username,
                 scope: scope(user, space)
               )
    end

    test "allows reusing the same username in another space" do
      first_space = generate(space())
      second_space = generate(space())
      first_user = generate(user())
      second_user = generate(user())
      first_membership = add_membership(first_space, first_user, :member)
      second_membership = add_membership(second_space, second_user, :member)

      assert {:ok, _membership} =
               Ash.update(
                 first_membership,
                 %{username: "shared"},
                 action: :set_username,
                 scope: scope(first_user, first_space)
               )

      assert {:ok, updated_membership} =
               Ash.update(
                 second_membership,
                 %{username: "shared"},
                 action: :set_username,
                 scope: scope(second_user, second_space)
               )

      assert updated_membership.username == "shared"
    end
  end

  describe "username suggestion" do
    test "returns the normalized external identity username for the current space" do
      space = generate(space())
      user = generate(user())
      add_membership(space, user, :member)
      %{identity: identity} = grant_active_telegram_access(space, user)

      assert {:ok, _identity} =
               Ash.update(
                 identity,
                 %{username: "@Telegram_User"},
                 action: :update,
                 authorize?: false,
                 domain: Wik.Access
               )

      assert {:ok, "telegram-user"} = Access.get_user_space_username_suggestion(user, space)
    end

    test "returns nil when there is no external identity username available" do
      space = generate(space())
      user = generate(user())
      add_membership(space, user, :member)
      grant_active_telegram_access(space, user)

      assert {:ok, nil} = Access.get_user_space_username_suggestion(user, space)
    end
  end

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
  end

  defp scope(actor, tenant) do
    %Scope{actor: actor, tenant: tenant}
  end
end
