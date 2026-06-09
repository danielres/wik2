defmodule WikWeb.SpaceAdminLiveTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Accounts.Membership

  test "space admins can access the admin page and see the admin nav link", %{conn: conn} do
    owner = generate(user())
    admin = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    add_membership(space, admin, :admin)
    grant_active_telegram_access(space, admin)

    {:ok, view, _html} =
      conn
      |> log_in(admin)
      |> live(~p"/#{space.slug}/admin")

    assert has_element?(view, "h1", "Admin")
    assert has_element?(view, "a[href='/#{space.slug}/admin']", "Admin")
  end

  test "space members cannot access the admin page or see the admin nav link", %{conn: conn} do
    owner = generate(user())
    member = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    add_membership(space, member, :member)
    grant_active_telegram_access(space, member)

    conn = log_in(conn, member)

    {:ok, view, _html} = live(conn, ~p"/#{space.slug}")
    refute has_element?(view, "a[href='/#{space.slug}/admin']", "Admin")

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/#{space.slug}/admin")
  end

  test "superadmins can access the admin page and see the admin nav link without space membership",
       %{conn: conn} do
    owner = generate(user())
    superadmin = generate(user(role: :superadmin))
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(superadmin)
      |> live(~p"/#{space.slug}/admin")

    assert has_element?(view, "h1", "Admin")
    assert has_element?(view, "a[href='/#{space.slug}/admin']", "Admin")
  end

  defp add_membership(space, user, type, attrs \\ %{}) do
    Ash.create!(
      Membership,
      Map.merge(%{space_id: space.id, type: type, user_id: user.id}, Enum.into(attrs, %{})),
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
