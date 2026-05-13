defmodule Wik.Accounts.GroupMembershipPresentationTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts
  alias Wik.Accounts.GroupUserRelation

  test "get_group_membership loads user and avatar_url" do
    user = generate(user())
    group = generate(group())
    add_membership(group, user, :member)
    %{identity: identity} = grant_active_telegram_access(group, user)

    assert {:ok, _identity} =
             Ash.update(
               identity,
               %{avatar_url: "https://telegram.example/avatar.png"},
               action: :update,
               authorize?: false,
               domain: Wik.Access
             )

    assert {:ok, membership} = Accounts.get_membership(group, user)
    assert membership.user.id == user.id
    assert membership.avatar_url == "https://telegram.example/avatar.png"
  end

  test "list_memberships_by_user_id returns memberships keyed by user id" do
    group = generate(group())
    first_user = generate(user())
    second_user = generate(user())
    outsider = generate(user())

    add_membership(group, first_user, :member, username: "first-user")
    add_membership(group, second_user, :admin)

    %{identity: identity} = grant_active_telegram_access(group, second_user)

    assert {:ok, _identity} =
             Ash.update(
               identity,
               %{avatar_url: "https://telegram.example/second.png"},
               action: :update,
               authorize?: false,
               domain: Wik.Access
             )

    assert {:ok, memberships} =
             Accounts.list_memberships_by_user_id(group.id, [
               first_user.id,
               second_user.id,
               outsider.id
             ])

    assert Map.keys(memberships) |> Enum.sort() == Enum.sort([first_user.id, second_user.id])
    assert memberships[first_user.id].username == "first-user"
    assert memberships[first_user.id].user.id == first_user.id
    assert memberships[first_user.id].avatar_url == nil
    assert memberships[second_user.id].user.id == second_user.id
    assert memberships[second_user.id].avatar_url == "https://telegram.example/second.png"
  end

  test "present_membership extracts the UI-facing membership fields" do
    user = generate(user())
    group = generate(group())
    add_membership(group, user, :member, username: "member-name")
    %{identity: identity} = grant_active_telegram_access(group, user)

    assert {:ok, _identity} =
             Ash.update(
               identity,
               %{avatar_url: "https://telegram.example/member.png"},
               action: :update,
               authorize?: false,
               domain: Wik.Access
             )

    assert {:ok, loaded_membership} = Accounts.get_membership(group, user)

    assert %{
             avatar_url: "https://telegram.example/member.png",
             user: presented_user,
             username: "member-name"
           } =
             Accounts.present_membership(loaded_membership)

    assert presented_user.id == user.id

    assert %{avatar_url: nil, user: nil, username: nil} = Accounts.present_membership(nil)
  end

  defp add_membership(group, user, type, opts \\ []) do
    membership =
      Ash.create!(
        GroupUserRelation,
        %{group_id: group.id, type: type, user_id: user.id},
        authorize?: false,
        domain: Wik.Accounts
      )

    case Keyword.get(opts, :username) do
      nil ->
        membership

      username ->
        Ash.update!(
          membership,
          %{username: username},
          action: :set_username,
          scope: %Wik.Scope{actor: user, tenant: group}
        )
    end
  end
end
