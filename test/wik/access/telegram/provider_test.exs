defmodule Wik.Access.Telegram.ProviderTest do
  use ExUnit.Case, async: true

  alias Wik.Access.Telegram.Provider, as: Telegram

  describe "verify_login/2" do
    test "accepts a valid Telegram Login Widget payload" do
      bot_token = "123456:secret"

      params =
        %{
          "auth_date" => DateTime.utc_now() |> DateTime.to_unix(:second) |> Integer.to_string(),
          "first_name" => "Ada",
          "id" => "42",
          "username" => "ada"
        }
        |> sign_login_params(bot_token)

      assert {:ok, %{user: user}} = Telegram.verify_login(params, bot_token)

      assert user["given_name"] == "Ada"
      assert user["preferred_username"] == "ada"
      assert user["sub"] == 42
    end

    test "rejects an invalid Telegram Login Widget payload" do
      bot_token = "123456:secret"

      params = %{
        "auth_date" => DateTime.utc_now() |> DateTime.to_unix(:second) |> Integer.to_string(),
        "first_name" => "Ada",
        "hash" => "invalid",
        "id" => "42"
      }

      assert {:error, _error} = Telegram.verify_login(params, bot_token)
    end
  end

  describe "get_chat_member/4" do
    test "returns the chat member from a successful Telegram response" do
      test_pid = self()

      http_get = fn url, opts ->
        send(test_pid, {:telegram_request, url, opts})

        {:ok,
         %Req.Response{
           status: 200,
           body: %{"ok" => true, "result" => %{"status" => "member", "user" => %{"id" => 42}}}
         }}
      end

      assert {:ok, %{"status" => "member", "user" => %{"id" => 42}}} =
               Telegram.get_chat_member("-100123", "42", "bot-token", http_get)

      assert_receive {:telegram_request, url, opts}
      assert url == "https://api.telegram.org/botbot-token/getChatMember"
      assert opts == [params: [chat_id: "-100123", user_id: "42"]]
    end

    test "returns a Telegram error when Telegram reports failure" do
      http_get = fn _url, _opts ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{"ok" => false, "description" => "Bad Request: user not found"}
         }}
      end

      assert {:error, {:telegram_error, "Bad Request: user not found"}} =
               Telegram.get_chat_member("-100123", "42", "bot-token", http_get)
    end

    test "returns an HTTP error when Telegram responds outside the success status" do
      http_get = fn _url, _opts ->
        {:ok, %Req.Response{status: 500, body: %{"ok" => false}}}
      end

      assert {:error, {:http_error, 500, %{"ok" => false}}} =
               Telegram.get_chat_member("-100123", "42", "bot-token", http_get)
    end
  end

  describe "source_attrs_from_update/1" do
    test "extracts pending source attrs from bot chat membership updates" do
      update = %{
        "my_chat_member" => %{
          "chat" => %{
            "id" => -100_123,
            "title" => "Hobbies",
            "type" => "supergroup"
          },
          "new_chat_member" => %{
            "status" => "member"
          }
        }
      }

      assert {:ok, attrs} = Telegram.source_attrs_from_update(update)

      assert attrs.provider_source_id == "-100123"
      assert attrs.title == "Hobbies"
      assert attrs.metadata["kind"] == "telegram_chat"
      assert attrs.metadata["chat"]["type"] == "supergroup"
    end

    test "ignores bot removal updates" do
      update = %{
        "my_chat_member" => %{
          "chat" => %{
            "id" => -100_123,
            "title" => "Hobbies",
            "type" => "supergroup"
          },
          "new_chat_member" => %{
            "status" => "left"
          }
        }
      }

      assert Telegram.source_attrs_from_update(update) == :ignore
    end

    test "ignores unrelated updates" do
      assert Telegram.source_attrs_from_update(%{"message" => %{"text" => "hello"}}) == :ignore
    end
  end

  describe "creator?/1" do
    test "returns true for Telegram creator status" do
      assert Telegram.creator?(%{"status" => "creator"})
    end

    test "returns false for non-creator statuses" do
      refute Telegram.creator?(%{"status" => "administrator"})
      refute Telegram.creator?(%{"status" => "member"})
      refute Telegram.creator?(%{"status" => "left"})
    end
  end

  describe "active_member?/1" do
    test "returns true for statuses that grant access" do
      assert Telegram.active_member?(%{"status" => "creator"})
      assert Telegram.active_member?(%{"status" => "administrator"})
      assert Telegram.active_member?(%{"status" => "member"})
    end

    test "returns false for statuses that do not grant access" do
      refute Telegram.active_member?(%{"status" => "left"})
      refute Telegram.active_member?(%{"status" => "kicked"})
    end
  end

  defp sign_login_params(params, bot_token) do
    secret = :crypto.hash(:sha256, bot_token)

    hash =
      :hmac
      |> :crypto.mac(:sha256, secret, data_check_string(params))
      |> Base.encode16(case: :lower)

    Map.put(params, "hash", hash)
  end

  defp data_check_string(params) do
    params
    |> Enum.map(fn {key, value} -> "#{key}=#{value}" end)
    |> Enum.sort()
    |> Enum.join("\n")
  end
end
