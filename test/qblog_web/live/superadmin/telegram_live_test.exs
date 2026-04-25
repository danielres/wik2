defmodule QblogWeb.Superadmin.TelegramLiveTest do
  use QblogWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Qblog.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Qblog.Access

  test "superadmin sees Telegram bot updates", %{conn: conn} do
    superadmin = generate(user(role: :superadmin))

    assert {:ok, _bot_update} =
             Access.telegram_create_bot_update(%{
               "channel_post" => %{
                 "chat" => %{"id" => -100_123, "title" => "Hobbies", "type" => "channel"},
                 "text" => "hello"
               },
               "update_id" => 123
             })

    {:ok, view, _html} =
      conn
      |> log_in(superadmin)
      |> live(~p"/_")

    assert has_element?(view, testid("telegram-bot-update-123"))
    assert render(view) =~ "channel_post"
    assert render(view) =~ "Hobbies"
  end

  test "normal users cannot see Telegram bot updates", %{conn: conn} do
    user = generate(user())

    assert {:error, {:redirect, %{to: "/"}}} =
             conn
             |> log_in(user)
             |> live(~p"/_")
  end

  test "anonymous users are redirected to sign in", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/_")
  end

  defp log_in(conn, user) do
    {:ok, token, _claims} = Jwt.token_for_user(user)
    user = Ash.Resource.set_metadata(user, %{token: token})

    conn
    |> init_test_session(%{})
    |> AuthHelpers.store_in_session(user)
  end
end
