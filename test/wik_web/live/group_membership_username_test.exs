defmodule WikWeb.GroupMembershipUsernameTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Accounts
  alias Wik.Accounts.GroupUserRelation

  test "group entry requires setting a membership username once", %{conn: conn} do
    user = generate(user())
    group = generate(group(author: user))
    add_membership(group, user, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(user)
      |> live(~p"/#{group.name}/tree")

    assert has_element?(view, testid("membership-username-dialog"))

    view
    |> form("#membership-username-form", form: %{"username" => "alice"})
    |> render_submit()

    refute has_element?(view, testid("membership-username-dialog"))
    assert render(view) =~ "/#{group.name}/wiki/members/alice"

    assert {:ok, membership} = Accounts.get_membership(group, user)
    assert membership.username == "alice"
  end

  test "username input is slugified during validation", %{conn: conn} do
    user = generate(user())
    group = generate(group(author: user))
    add_membership(group, user, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(user)
      |> live(~p"/#{group.name}/tree")

    html =
      view
      |> form("#membership-username-form", form: %{"username" => "A B_C"})
      |> render_change()

    assert html =~ ~s(value="a-b-c")
  end

  test "superadmin without a membership is not blocked by the username modal", %{conn: conn} do
    owner = generate(user())
    superadmin = generate(user(role: :superadmin))
    group = generate(group(author: owner))
    add_membership(group, owner, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(superadmin)
      |> live(~p"/#{group.name}/tree")

    refute has_element?(view, testid("membership-username-dialog"))
  end

  defp add_membership(group, user, type) do
    Ash.create!(
      GroupUserRelation,
      %{group_id: group.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
  end

  defp log_in(conn, user) do
    {:ok, token, _claims} = Jwt.token_for_user(user)
    user = Ash.Resource.set_metadata(user, %{token: token})

    conn
    |> init_test_session(%{})
    |> AuthHelpers.store_in_session(user)
  end
end
