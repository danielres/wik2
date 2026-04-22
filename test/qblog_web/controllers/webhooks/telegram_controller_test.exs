defmodule QblogWeb.Webhooks.TelegramControllerTest do
  use QblogWeb.ConnCase

  alias Qblog.Access.Source
  alias Qblog.Access.Telegram.BotUpdate

  require Ash.Query

  test "creates a pending source from a bot chat membership update", %{conn: conn} do
    conn = post(conn, ~p"/webhooks/telegram", bot_added_update(title: "Hobbies"))

    assert json_response(conn, 200) == %{"ok" => true}

    assert {:ok, source} =
             Source
             |> Ash.Query.filter(provider == :telegram and provider_source_id == "-100123")
             |> Ash.read_one(authorize?: false)

    assert source.title == "Hobbies"
    assert source.status == :pending
    assert source.group_id == nil
    assert source.claimed_by_user_id == nil
    assert source.metadata["kind"] == "telegram_chat"

    assert {:ok, bot_update} =
             BotUpdate
             |> Ash.Query.filter(update_id == 123)
             |> Ash.read_one(authorize?: false)

    assert bot_update.update_type == "my_chat_member"
  end

  test "refreshes source metadata without resetting claimed state", %{conn: conn} do
    group = Qblog.TestGenerators.generate(Qblog.TestGenerators.group())
    user = Qblog.TestGenerators.generate(Qblog.TestGenerators.user())

    assert {:ok, source} =
             Ash.create(
               Source,
               %{
                 claimed_at: DateTime.utc_now(),
                 claimed_by_user_id: user.id,
                 group_id: group.id,
                 metadata: %{"kind" => "telegram_chat"},
                 provider: :telegram,
                 provider_source_id: "-100123",
                 status: :active,
                 title: "Old title"
               },
               authorize?: false
             )

    conn = post(conn, ~p"/webhooks/telegram", bot_added_update(title: "New title"))

    assert json_response(conn, 200) == %{"ok" => true}

    assert {:ok, source} = Ash.get(Source, source.id, authorize?: false)

    assert source.title == "New title"
    assert source.status == :active
    assert source.group_id == group.id
    assert source.claimed_by_user_id == user.id
  end

  test "ignores unrelated Telegram updates", %{conn: conn} do
    conn =
      post(conn, ~p"/webhooks/telegram", %{
        "message" => %{"text" => "hello"},
        "update_id" => 124
      })

    assert json_response(conn, 200) == %{"ok" => true}

    assert {:ok, []} = Ash.read(Source, authorize?: false)

    assert {:ok, bot_update} =
             BotUpdate
             |> Ash.Query.filter(update_id == 124)
             |> Ash.read_one(authorize?: false)

    assert bot_update.update_type == "message"
  end

  defp bot_added_update(opts) do
    title = Keyword.fetch!(opts, :title)

    %{
      "my_chat_member" => %{
        "chat" => %{
          "id" => -100_123,
          "title" => title,
          "type" => "supergroup"
        },
        "new_chat_member" => %{
          "status" => "member"
        }
      },
      "update_id" => 123
    }
  end
end
