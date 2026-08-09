defmodule WikWeb.MembersLiveTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Accounts.Membership

  test "shows when each member last connected to the space", %{conn: conn} do
    owner = generate(user())
    seen_member = generate(user())
    never_seen_member = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    seen_membership = add_membership(space, seen_member, :member)
    never_seen_membership = add_membership(space, never_seen_member, :member)

    seen_membership =
      Ash.update!(seen_membership, %{},
        action: :mark_seen,
        authorize?: false,
        domain: Wik.Accounts
      )

    expected_last_seen =
      seen_membership.last_seen_at
      |> Utils.Tz.to_local!("Europe/Warsaw")
      |> Utils.Time.precise()

    expected_member_since =
      seen_membership.inserted_at
      |> Utils.Tz.to_local!("Europe/Warsaw")
      |> Utils.Time.precise()

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> put_connect_params(%{"tz" => "Europe/Warsaw"})
      |> live(~p"/#{space.slug}/members")

    assert has_element?(
             view,
             testid("member-row-last-seen-#{seen_membership.id}"),
             "Last seen: just now"
           )

    assert has_element?(
             view,
             ~s(#{testid("member-row-last-seen-#{seen_membership.id}")}[data-tip="Last seen #{expected_last_seen}"])
           )

    assert has_element?(
             view,
             ~s(span[data-tip="Member since #{expected_member_since}"])
           )

    assert has_element?(
             view,
             testid("member-row-last-seen-#{never_seen_membership.id}"),
             "Last seen: never"
           )
  end

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
