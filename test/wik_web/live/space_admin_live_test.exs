defmodule WikWeb.SpaceAdminLiveTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Access.ExternalIdentity
  alias Wik.Access.Grant
  alias Wik.Access.Source
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
    assert has_element?(view, "#space-admin-access-sources")
  end

  test "space owners can see the admin access section", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    grant_active_telegram_access(space, owner)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/admin")

    assert has_element?(view, "h1", "Admin")
    assert has_element?(view, "#space-admin-access-sources")
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
    assert has_element?(view, "#space-admin-access-sources")
  end

  test "admin page renders empty access state without sources", %{conn: conn} do
    owner = generate(user())
    superadmin = generate(user(role: :superadmin))
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(superadmin)
      |> live(~p"/#{space.slug}/admin")

    assert has_element?(view, "#space-admin-access-sources")
    assert has_element?(view, "[data-testid='access-sources-empty']", "No access sources yet.")
  end

  test "admin access sources only render active grants for each source", %{conn: conn} do
    owner = generate(user())
    first_member = generate(user())
    second_member = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    add_membership(space, first_member, :member)
    add_membership(space, second_member, :member)
    first_source = create_source(space, owner, "First Telegram Group")
    second_source = create_source(space, owner, "Second Telegram Group")
    first_identity = create_external_identity(first_member, "telegram-first")
    second_identity = create_external_identity(second_member, "telegram-second")
    create_grant(first_source, first_identity, first_member, :active)
    create_grant(second_source, first_identity, first_member, :inactive)
    create_grant(second_source, second_identity, second_member, :active)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/admin")

    assert has_element?(view, "#access-source-#{first_source.id}", "telegram-first")
    refute has_element?(view, "#access-source-#{first_source.id}", "telegram-second")
    assert has_element?(view, "#access-source-#{second_source.id}", "telegram-second")
    refute has_element?(view, "#access-source-#{second_source.id}", "telegram-first")
  end

  defp add_membership(space, user, type, attrs \\ %{}) do
    Ash.create!(
      Membership,
      Map.merge(%{space_id: space.id, type: type, user_id: user.id}, Enum.into(attrs, %{})),
      authorize?: false
    )
  end

  defp create_source(space, user, title) do
    Ash.create!(
      Source,
      %{
        claimed_at: DateTime.utc_now(),
        claimed_by_user_id: user.id,
        space_id: space.id,
        metadata: %{"chat" => %{"type" => "group"}},
        provider: :telegram,
        provider_source_id: "telegram-source-#{System.unique_integer([:positive])}",
        status: :active,
        title: title
      },
      authorize?: false,
      domain: Wik.Access
    )
  end

  defp create_external_identity(user, provider_user_id) do
    Ash.create!(
      ExternalIdentity,
      %{
        display_name: provider_user_id,
        provider: :telegram,
        provider_user_id: provider_user_id,
        user_id: user.id
      },
      authorize?: false,
      domain: Wik.Access
    )
  end

  defp create_grant(source, identity, user, status) do
    Ash.create!(
      Grant,
      %{
        external_identity_id: identity.id,
        last_verified_at: DateTime.utc_now(),
        source_id: source.id,
        status: status,
        user_id: user.id
      },
      authorize?: false,
      domain: Wik.Access
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
