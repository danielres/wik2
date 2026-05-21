defmodule Wik.Accounts.ListOwnedSpacesTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts
  alias Wik.Accounts.Membership

  test "lists only spaces where the user has an owner membership" do
    user = generate(user())
    owned_space = generate(space(author: user, name: "owned-space"))
    admin_space = generate(space(name: "admin-space"))
    member_space = generate(space(name: "member-space"))
    other_owned_space = generate(space(name: "other-owned-space"))

    create_membership(owned_space, user, :owner)
    create_membership(admin_space, user, :admin)
    create_membership(member_space, user, :member)
    create_membership(other_owned_space, generate(user()), :owner)

    assert {:ok, spaces} = Accounts.list_owned_spaces(user)

    assert Enum.map(spaces, & &1.id) == [owned_space.id]
  end

  defp create_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
  end
end
