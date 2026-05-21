defmodule WikWeb.ErrorTrackerContextTest do
  use ExUnit.Case, async: true

  alias Wik.Accounts.User
  alias Wik.Scope
  alias WikWeb.ErrorTrackerContext

  test "does not include full email in error tracker user context" do
    user = %User{id: "user-1", email: "ada@example.com", role: :user}
    scope = %Scope{tenant: %{id: "space-1", name: "Space One", slug: "space-one"}}

    context =
      ErrorTrackerContext.build(%{
        assigns: %{current_scope: scope, current_user: user}
      })

    assert context.user.id == "user-1"
    assert context.user.username == "ada"
    assert context.user.role == "user"
    refute Map.has_key?(context.user, :email)
  end
end
