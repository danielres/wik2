defmodule QblogWeb.MeLiveTest do
  use QblogWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Qblog.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Qblog.Access.ExternalIdentity
  alias Qblog.Access.Grant
  alias Qblog.Access.Source
  alias Qblog.Accounts.GroupUserRelation

  test "renders connected identity and access grant instead of global username and email details",
       %{
         conn: conn
       } do
    user = generate(user(email: nil))
    group = generate(group())

    create_membership(group, user)

    create_telegram_access(group, user,
      display_name: "Ada Lovelace",
      username: "ada"
    )

    {:ok, view, _html} =
      conn
      |> log_in(user)
      |> live(~p"/me")

    assert has_element?(view, testid("me-access-grants"))
    assert has_element?(view, testid("me-connected-identities"))
    assert render(view) =~ "@ada"
    assert render(view) =~ group.name
    assert render(view) =~ "member"
    refute render(view) =~ "<th>username</th>"
    refute render(view) =~ "<th>email</th>"
  end

  test "renders the membership type for access grants", %{conn: conn} do
    user = generate(user(email: nil))
    group = generate(group())

    create_membership(group, user, :admin)

    create_telegram_access(group, user,
      display_name: "Ada Lovelace",
      username: "ada"
    )

    {:ok, view, _html} =
      conn
      |> log_in(user)
      |> live(~p"/me")

    assert has_element?(view, testid("me-access-grants"))
    assert render(view) =~ "admin"
  end

  test "renders connected identity without requiring an access grant", %{conn: conn} do
    user = generate(user(email: nil))

    create_telegram_identity(user,
      display_name: "Ada Lovelace",
      username: "ada"
    )

    {:ok, view, _html} =
      conn
      |> log_in(user)
      |> live(~p"/me")

    assert has_element?(view, testid("me-connected-identities"))
    refute has_element?(view, testid("me-access-grants"))
    assert render(view) =~ "@ada"
    assert render(view) =~ "No access grants yet."
  end

  test "renders Telegram display name when username is missing", %{conn: conn} do
    user = generate(user(email: nil))
    group = generate(group())

    create_membership(group, user)

    create_telegram_access(group, user,
      display_name: "Ada Lovelace",
      username: nil
    )

    {:ok, view, _html} =
      conn
      |> log_in(user)
      |> live(~p"/me")

    assert render(view) =~ "Ada Lovelace"
  end

  test "renders provider id when username and display name are missing", %{conn: conn} do
    user = generate(user(email: nil))
    group = generate(group())

    create_membership(group, user)

    create_telegram_access(group, user,
      display_name: nil,
      provider_user_id: "telegram-user-42",
      username: nil
    )

    {:ok, view, _html} =
      conn
      |> log_in(user)
      |> live(~p"/me")

    assert render(view) =~ "telegram:telegram-user-42"
  end

  test "explains that owner access bypasses access grants", %{conn: conn} do
    user = generate(user(email: nil))
    group = generate(group())

    create_membership(group, user, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(user)
      |> live(~p"/me")

    assert has_element?(view, testid("owner-access-bypass"))
    assert render(view) =~ "Owner access does not depend on access grant status."
    assert render(view) =~ group.name
  end

  test "explains that superadmin access bypasses access grants", %{conn: conn} do
    user = generate(user(email: nil, role: :superadmin))

    {:ok, view, _html} =
      conn
      |> log_in(user)
      |> live(~p"/me")

    assert has_element?(view, testid("superadmin-access-bypass"))
    assert render(view) =~ "Superadmins can access spaces directly"
  end

  defp create_membership(group, user, type \\ :member) do
    Ash.create!(
      GroupUserRelation,
      %{
        group_id: group.id,
        type: type,
        user_id: user.id
      },
      authorize?: false,
      domain: Qblog.Accounts
    )
  end

  defp create_telegram_access(group, user, opts) do
    source =
      Ash.create!(
        Source,
        %{
          claimed_at: DateTime.utc_now(),
          claimed_by_user_id: user.id,
          group_id: group.id,
          provider: :telegram,
          provider_source_id: "telegram-source-#{System.unique_integer([:positive])}",
          status: :active,
          title: "Telegram Group"
        },
        authorize?: false,
        domain: Qblog.Access
      )

    identity = create_telegram_identity(user, opts)

    Ash.create!(
      Grant,
      %{
        external_identity_id: identity.id,
        last_verified_at: DateTime.utc_now(),
        source_id: source.id,
        status: :active,
        user_id: user.id
      },
      authorize?: false,
      domain: Qblog.Access
    )
  end

  defp create_telegram_identity(user, opts) do
    Ash.create!(
      ExternalIdentity,
      %{
        display_name: Keyword.get(opts, :display_name),
        provider: :telegram,
        provider_user_id:
          Keyword.get_lazy(opts, :provider_user_id, fn ->
            "telegram-user-#{System.unique_integer([:positive])}"
          end),
        username: Keyword.get(opts, :username),
        user_id: user.id
      },
      authorize?: false,
      domain: Qblog.Access
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
