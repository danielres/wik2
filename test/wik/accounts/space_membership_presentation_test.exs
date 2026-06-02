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

  test "present_membership prefers membership username, then external identity username, then external identity display name" do
    space = generate(space())

    username_user = generate(user(email: nil))
    display_name_user = generate(user(email: nil))

    add_membership(space, username_user, :member)
    add_membership(space, display_name_user, :member)

    %{identity: username_identity} = grant_active_telegram_access(space, username_user)

    assert {:ok, _identity} =
             Ash.update(
               username_identity,
               %{username: "telegram-user", display_name: "Telegram User"},
               action: :update,
               authorize?: false,
               domain: Wik.Access
             )

    %{identity: display_name_identity} = grant_active_telegram_access(space, display_name_user)

    assert {:ok, _identity} =
             Ash.update(
               display_name_identity,
               %{username: nil, display_name: "Only Display Name"},
               action: :update,
               authorize?: false,
               domain: Wik.Access
             )

    assert {:ok, username_membership} = Accounts.get_membership(space, username_user)
    assert {:ok, display_name_membership} = Accounts.get_membership(space, display_name_user)

    assert username_membership.user.external_identities != []
    assert display_name_membership.user.external_identities != []

    assert Accounts.present_membership(%{username_membership | username: "space-username"}).display_name ==
             "space-username"

    assert Accounts.present_membership(username_membership).display_name == "telegram-user"

    assert Accounts.present_membership(display_name_membership).display_name ==
             "Only Display Name"
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
