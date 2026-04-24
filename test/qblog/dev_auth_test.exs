defmodule Qblog.DevAuthTest do
  use Qblog.DataCase

  alias Qblog.DevAuth

  test "sign_in_superadmin creates the dev superadmin once and reuses it" do
    assert {:ok, user_1} = DevAuth.sign_in_superadmin()
    assert user_1.role == :superadmin
    assert to_string(user_1.email) == "dev-superadmin@local.dev"

    assert {:ok, user_2} = DevAuth.sign_in_superadmin()
    assert user_2.id == user_1.id
  end
end
