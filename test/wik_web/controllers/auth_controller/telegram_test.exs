defmodule WikWeb.AuthController.TelegramTest do
  use WikWeb.ConnCase

  alias Wik.Access.ExternalIdentity

  import ExUnit.CaptureLog

  require Ash.Query

  setup do
    old_bot_token = System.get_env("TELEGRAM_BOT_TOKEN")
    System.put_env("TELEGRAM_BOT_TOKEN", "123456:secret")

    on_exit(fn ->
      case old_bot_token do
        nil -> System.delete_env("TELEGRAM_BOT_TOKEN")
        bot_token -> System.put_env("TELEGRAM_BOT_TOKEN", bot_token)
      end
    end)
  end

  test "signs in with valid Telegram Login Widget params", %{conn: conn} do
    conn =
      get(conn, ~p"/auth/telegram/callback", valid_telegram_params(return_to: "/me"))

    assert redirected_to(conn) == "/me"
    assert get_session(conn, "user_token") |> is_binary()

    assert {:ok, identity} =
             ExternalIdentity
             |> Ash.Query.filter(provider == :telegram and provider_user_id == "42")
             |> Ash.read_one(authorize?: false, load: [:user])

    assert identity.display_name == "Ada Lovelace"
    assert identity.username == "ada"
    assert identity.user.email == nil
  end

  test "rejects invalid Telegram Login Widget params", %{conn: conn} do
    {conn, _log} =
      with_log(fn ->
        get(conn, ~p"/auth/telegram/callback", %{
          "auth_date" => DateTime.utc_now() |> DateTime.to_unix(:second) |> Integer.to_string(),
          "first_name" => "Ada",
          "hash" => "invalid",
          "id" => "42"
        })
      end)

    assert redirected_to(conn) == ~p"/sign-in"
    assert get_session(conn, "user_token") == nil
  end

  test "prevents open redirects", %{conn: conn} do
    conn =
      get(
        conn,
        ~p"/auth/telegram/callback",
        valid_telegram_params(return_to: "https://evil.example")
      )

    assert redirected_to(conn) == ~p"/"
  end

  defp valid_telegram_params(opts) do
    return_to = Keyword.fetch!(opts, :return_to)
    bot_token = System.fetch_env!("TELEGRAM_BOT_TOKEN")

    %{
      "auth_date" => DateTime.utc_now() |> DateTime.to_unix(:second) |> Integer.to_string(),
      "first_name" => "Ada",
      "id" => "42",
      "last_name" => "Lovelace",
      "photo_url" => "https://telegram.example/ada.png",
      "return_to" => return_to,
      "username" => "ada"
    }
    |> sign_login_params(bot_token)
  end

  defp sign_login_params(%{"return_to" => return_to} = params, bot_token) do
    telegram_params = Map.delete(params, "return_to")
    secret = :crypto.hash(:sha256, bot_token)

    hash =
      :hmac
      |> :crypto.mac(:sha256, secret, data_check_string(telegram_params))
      |> Base.encode16(case: :lower)

    telegram_params
    |> Map.put("hash", hash)
    |> Map.put("return_to", return_to)
  end

  defp data_check_string(params) do
    params
    |> Enum.map(fn {key, value} -> "#{key}=#{value}" end)
    |> Enum.sort()
    |> Enum.join("\n")
  end
end
