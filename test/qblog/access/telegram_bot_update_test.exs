defmodule Qblog.Access.TelegramBotUpdateTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Access

  test "stores Telegram bot updates" do
    update = %{
      "message" => %{"text" => "hello"},
      "update_id" => 123
    }

    assert {:ok, bot_update} = Access.telegram_create_bot_update(update)

    assert bot_update.update_id == 123
    assert bot_update.update_type == "message"
    assert bot_update.payload == update
  end

  test "only superadmins can read Telegram bot updates" do
    superadmin = generate(user(role: :superadmin))
    user = generate(user())

    assert {:ok, bot_update} =
             Access.telegram_create_bot_update(%{
               "message" => %{"text" => "hello"},
               "update_id" => 123
             })

    assert Ash.can?({bot_update, :read}, superadmin)
    refute Ash.can?({bot_update, :read}, user)
  end

  test "lists Telegram bot updates newest first for superadmins" do
    superadmin = generate(user(role: :superadmin))

    assert {:ok, older} =
             Access.telegram_create_bot_update(%{
               "message" => %{"text" => "older"},
               "update_id" => 123
             })

    assert {:ok, newer} =
             Access.telegram_create_bot_update(%{
               "channel_post" => %{"text" => "newer"},
               "update_id" => 124
             })

    assert {:ok, bot_updates} = Access.telegram_list_bot_updates(superadmin)

    assert Enum.map(bot_updates, & &1.id) == [newer.id, older.id]
  end
end
