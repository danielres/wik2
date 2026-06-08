defmodule WikWeb.MembersLiveTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Accounts.Membership

  test "updating a membership type refreshes the members list", %{conn: conn} do
    owner = generate(user())
    member = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    member_membership = add_membership(space, member, :member)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/members")

    assert has_element?(view, testid("member-row-role-#{member_membership.id}"), "Member")

    view
    |> element(~s(button[phx-click="toggle_edit_mode"]))
    |> render_click()

    view
    |> element(
      ~s(button[phx-click="membership_type_change_start"][phx-value-membership_id="#{member_membership.id}"])
    )
    |> render_click()

    view
    |> form("#membership-type-form", form: %{"type" => "admin"})
    |> render_submit()

    assert has_element?(view, testid("member-row-role-#{member_membership.id}"), "Admin")
  end

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false
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
