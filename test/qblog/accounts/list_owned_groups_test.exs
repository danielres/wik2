defmodule Qblog.Accounts.ListOwnedGroupsTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Accounts
  alias Qblog.Accounts.GroupUserRelation

  test "lists only groups where the user has an owner membership" do
    user = generate(user())
    owned_group = generate(group(author: user, name: "owned-group"))
    admin_group = generate(group(name: "admin-group"))
    member_group = generate(group(name: "member-group"))
    other_owned_group = generate(group(name: "other-owned-group"))

    create_membership(owned_group, user, :owner)
    create_membership(admin_group, user, :admin)
    create_membership(member_group, user, :member)
    create_membership(other_owned_group, generate(user()), :owner)

    assert {:ok, groups} = Accounts.list_owned_groups(user)

    assert Enum.map(groups, & &1.id) == [owned_group.id]
  end

  defp create_membership(group, user, type) do
    Ash.create!(
      GroupUserRelation,
      %{group_id: group.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Qblog.Accounts
    )
  end
end
