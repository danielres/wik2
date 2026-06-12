defmodule WikWeb.Auth.SignInLiveTest do
  use WikWeb.ConnCase

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers

  setup do
    old_bot_username = System.get_env("TELEGRAM_BOT_USERNAME")
    System.put_env("TELEGRAM_BOT_USERNAME", "wik_test_bot")

    on_exit(fn ->
      case old_bot_username do
        nil -> System.delete_env("TELEGRAM_BOT_USERNAME")
        bot_username -> System.put_env("TELEGRAM_BOT_USERNAME", bot_username)
      end
    end)
  end

  test "renders Google and Telegram login entrypoints for anonymous users", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sign-in")

    assert has_element?(view, testid("sign-in-page"))
    assert has_element?(view, testid("google-sign-in"))
    assert has_element?(view, "#telegram-login")
    refute has_element?(view, testid("dev-sign-in"))
    refute has_element?(view, testid("dev-sign-in-superadmin"))
    refute has_element?(view, testid("telegram-sources-page"))
    refute has_element?(view, testid("telegram-sources-empty"))
  end

  test "redirects authenticated users away from sign in", %{conn: conn} do
    user = generate(user())

    assert {:error, {:redirect, %{to: "/"}}} =
             conn
             |> log_in(user)
             |> live(~p"/sign-in")
  end

  defp log_in(conn, user) do
    {:ok, token, _claims} = Jwt.token_for_user(user)
    user = Ash.Resource.set_metadata(user, %{token: token})

    conn
    |> init_test_session(%{})
    |> AuthHelpers.store_in_session(user)
  end
end
