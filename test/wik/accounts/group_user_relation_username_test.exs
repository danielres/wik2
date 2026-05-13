defmodule Wik.Accounts.GroupUserRelationUsernameTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Access
  alias Wik.Accounts.GroupUserRelation
  alias Wik.Scope

  describe "set_username action" do
    test "sets the username once for the membership owner" do
      group = generate(group())
      user = generate(user())
      membership = add_membership(group, user, :member)

      assert {:ok, updated_membership} =
               Ash.update(
                 membership,
                 %{username: "alice"},
                 action: :set_username,
                 scope: scope(user, group)
               )

      assert updated_membership.username == "alice"
    end

    test "rejects changing the username after it has been set" do
      group = generate(group())
      user = generate(user())
      membership = add_membership(group, user, :member)

      assert {:ok, membership} =
               Ash.update(
                 membership,
                 %{username: "alice"},
                 action: :set_username,
                 scope: scope(user, group)
               )

      assert {:error, _error} =
               Ash.update(
                 membership,
                 %{username: "bob"},
                 action: :set_username,
                 scope: scope(user, group)
               )
    end

    test "enforces uniqueness within a group" do
      group = generate(group())
      first_user = generate(user())
      second_user = generate(user())
      first_membership = add_membership(group, first_user, :member)
      second_membership = add_membership(group, second_user, :member)

      assert {:ok, _membership} =
               Ash.update(
                 first_membership,
                 %{username: "shared"},
                 action: :set_username,
                 scope: scope(first_user, group)
               )

      assert {:error, _error} =
               Ash.update(
                 second_membership,
                 %{username: "shared"},
                 action: :set_username,
                 scope: scope(second_user, group)
               )
    end

    test "rejects usernames that do not match the slug format" do
      group = generate(group())
      user = generate(user())
      membership = add_membership(group, user, :member)

      assert {:error, _error} =
               Ash.update(
                 membership,
                 %{username: "not valid"},
                 action: :set_username,
                 scope: scope(user, group)
               )
    end

    test "rejects usernames with underscores" do
      group = generate(group())
      user = generate(user())
      membership = add_membership(group, user, :member)

      assert {:error, _error} =
               Ash.update(
                 membership,
                 %{username: "not_valid"},
                 action: :set_username,
                 scope: scope(user, group)
               )
    end

    test "allows reusing the same username in another group" do
      first_group = generate(group())
      second_group = generate(group())
      first_user = generate(user())
      second_user = generate(user())
      first_membership = add_membership(first_group, first_user, :member)
      second_membership = add_membership(second_group, second_user, :member)

      assert {:ok, _membership} =
               Ash.update(
                 first_membership,
                 %{username: "shared"},
                 action: :set_username,
                 scope: scope(first_user, first_group)
               )

      assert {:ok, updated_membership} =
               Ash.update(
                 second_membership,
                 %{username: "shared"},
                 action: :set_username,
                 scope: scope(second_user, second_group)
               )

      assert updated_membership.username == "shared"
    end
  end

  describe "username suggestion" do
    test "returns the normalized external identity username for the current group" do
      group = generate(group())
      user = generate(user())
      add_membership(group, user, :member)
      %{identity: identity} = grant_active_telegram_access(group, user)

      assert {:ok, _identity} =
               Ash.update(
                 identity,
                 %{username: "@Telegram_User"},
                 action: :update,
                 authorize?: false,
                 domain: Wik.Access
               )

      assert {:ok, "telegram-user"} = Access.get_user_group_username_suggestion(user, group)
    end

    test "returns nil when there is no external identity username available" do
      group = generate(group())
      user = generate(user())
      add_membership(group, user, :member)
      grant_active_telegram_access(group, user)

      assert {:ok, nil} = Access.get_user_group_username_suggestion(user, group)
    end
  end

  defp add_membership(group, user, type) do
    Ash.create!(
      GroupUserRelation,
      %{group_id: group.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
  end

  defp scope(actor, tenant) do
    %Scope{actor: actor, tenant: tenant}
  end
end
