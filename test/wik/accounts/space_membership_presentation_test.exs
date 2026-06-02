defmodule Wik.Accounts.SpaceMembershipPresentationTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts
  alias Wik.Accounts.Membership

  test "get_space_membership loads user and avatar_url" do
    user = generate(user())
    space = generate(space())
    add_membership(space, user, :member)
    %{identity: identity} = grant_active_telegram_access(space, user)

    assert {:ok, _identity} =
             Ash.update(
               identity,
               %{avatar_url: "https://telegram.example/avatar.png"},
               action: :update,
               authorize?: false,
               domain: Wik.Access
             )

    assert {:ok, membership} = Accounts.get_membership(space, user)
    assert membership.user.id == user.id
    assert membership.avatar_url == "https://telegram.example/avatar.png"
  end

  test "list_memberships_by_user_id returns memberships keyed by user id" do
    space = generate(space())
    first_user = generate(user())
    second_user = generate(user())
    outsider = generate(user())

    add_membership(space, first_user, :member, username: "first-user")
    add_membership(space, second_user, :admin)

    %{identity: identity} = grant_active_telegram_access(space, second_user)

    assert {:ok, _identity} =
             Ash.update(
               identity,
               %{avatar_url: "https://telegram.example/second.png"},
               action: :update,
               authorize?: false,
               domain: Wik.Access
             )

    assert {:ok, memberships} =
             Accounts.list_memberships_by_user_id(space.id, [
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

  defp add_membership(space, user, type, opts \\ []) do
    membership =
      Ash.create!(
        Membership,
        %{space_id: space.id, type: type, user_id: user.id},
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
          scope: %Wik.Scope{actor: user, tenant: space}
        )
    end
  end
end
