defmodule QblogWeb.Auth.TelegramSourcesLiveTest do
  use QblogWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Qblog.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers

  test "redirects anonymous users to sign in", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/auth/telegram")
  end

  test "renders Telegram source management for authenticated users", %{conn: conn} do
    user = generate(user())

    {:ok, view, _html} =
      conn
      |> log_in(user)
      |> live(~p"/auth/telegram")

    assert has_element?(view, testid("telegram-sources-page"))
    assert has_element?(view, testid("telegram-sources-empty"))
    refute has_element?(view, "#telegram-login")
  end

  defp log_in(conn, user) do
    {:ok, token, _claims} = Jwt.token_for_user(user)
    user = Ash.Resource.set_metadata(user, %{token: token})

    conn
    |> init_test_session(%{})
    |> AuthHelpers.store_in_session(user)
  end
end
