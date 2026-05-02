defmodule Qblog.DevAuthTest do
  use Qblog.DataCase

  import Qblog.TestGenerators

  alias Qblog.DevAuth

  test "list_sign_in_users returns existing users in stable dev sign-in order" do
    superadmin = generate(user(email: nil, role: :superadmin))
    another_user = generate(user(email: "ada@example.com"))
    regular_user = generate(user(email: "zoe@example.com"))

    assert {:ok, users} = DevAuth.list_sign_in_users()

    filtered_user_ids =
      users
      |> Enum.map(& &1.id)
      |> Enum.filter(&(&1 in [superadmin.id, another_user.id, regular_user.id]))

    assert filtered_user_ids == [superadmin.id, another_user.id, regular_user.id]
  end

  test "sign_in_user returns an existing user by id" do
    user = generate(user(email: nil))

    assert {:ok, signed_in_user} = DevAuth.sign_in_user(user.id)
    assert signed_in_user.id == user.id
    assert signed_in_user.email == user.email
  end

  test "sign_in_user returns an error when the user does not exist" do
    assert {:error, :user_not_found} =
             DevAuth.sign_in_user("00000000-0000-0000-0000-000000000000")
  end

  test "sign_in_superadmin creates the dev superadmin once and reuses it" do
    assert {:ok, user_1} = DevAuth.sign_in_superadmin()
    assert user_1.role == :superadmin
    assert to_string(user_1.email) == "dev-superadmin@local.dev"

    assert {:ok, user_2} = DevAuth.sign_in_superadmin()
    assert user_2.id == user_1.id
  end
end
