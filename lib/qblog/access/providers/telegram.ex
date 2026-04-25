defmodule Qblog.Access.Providers.Telegram do
  alias Assent.Strategy.Telegram, as: AssentTelegram
  alias Qblog.Access.Telegram.Bot.Update.Summary

  @active_member_statuses ~w(member administrator creator)
  @api_url "https://api.telegram.org"

  def verify_login(params) do
    params |> verify_login(bot_token())
  end

  def verify_login(params, bot_token) when is_map(params) and is_binary(bot_token) do
    AssentTelegram.callback(
      [
        authorization_channel: :login_widget,
        bot_token: bot_token
      ],
      params
    )
  end

  def get_chat_member(chat_id, telegram_user_id) do
    get_chat_member(chat_id, telegram_user_id, bot_token(), &Req.get/2)
  end

  def get_chat_member(chat_id, telegram_user_id, bot_token, http_get)
      when is_binary(bot_token) and is_function(http_get, 2) do
    "#{@api_url}/bot#{bot_token}/getChatMember"
    |> http_get.(params: [chat_id: chat_id, user_id: telegram_user_id])
    |> chat_member_from_response()
  end

  def bot_update_attrs_from_update(%{"update_id" => update_id} = update) do
    %{
      payload: update,
      summary: struct(Summary, summary(update)),
      update_id: update_id
    }
  end

  def source_attrs_from_update(%{
        "my_chat_member" => %{
          "chat" => chat,
          "new_chat_member" => %{"status" => status}
        }
      })
      when status in @active_member_statuses do
    {:ok,
     %{
       metadata: %{
         "chat" => chat,
         "kind" => "telegram_chat"
       },
       provider_source_id: chat["id"] |> to_string(),
       title: chat_title(chat)
     }}
  end

  def source_attrs_from_update(%{"my_chat_member" => _my_chat_member}), do: :ignore
  def source_attrs_from_update(_update), do: :ignore

  def creator?(%{"status" => "creator"}), do: true
  def creator?(_chat_member), do: false

  def active_member?(%{"status" => status}), do: status in @active_member_statuses
  def active_member?(_chat_member), do: false

  defp chat_title(%{"title" => title}) when is_binary(title), do: title
  defp chat_title(%{"username" => username}) when is_binary(username), do: username
  defp chat_title(%{"id" => chat_id}), do: chat_id |> to_string()
  defp chat_title(nil), do: nil

  defp chat_id(%{"id" => chat_id}), do: chat_id |> to_string()
  defp chat_id(nil), do: nil

  defp chat_type(%{"type" => type}), do: type
  defp chat_type(nil), do: nil

  defp summary(%{"my_chat_member" => chat_member} = update) do
    %{
      actor_name: user_name(chat_member["from"]),
      actor_username: user_username(chat_member["from"]),
      chat_id: chat_id(chat_member["chat"]),
      chat_title: chat_title(chat_member["chat"]),
      chat_type: chat_type(chat_member["chat"]),
      message_text: nil,
      status_from: member_status(chat_member["old_chat_member"]),
      status_to: member_status(chat_member["new_chat_member"]),
      update_type: update_type(update)
    }
  end

  defp summary(%{"message" => message} = update) do
    message_summary(update, message)
  end

  defp summary(%{"channel_post" => message} = update) do
    message_summary(update, message)
  end

  defp summary(update) do
    %{
      actor_name: nil,
      actor_username: nil,
      chat_id: nil,
      chat_title: nil,
      chat_type: nil,
      message_text: nil,
      status_from: nil,
      status_to: nil,
      update_type: update_type(update)
    }
  end

  defp message_summary(update, message) do
    %{
      actor_name: user_name(message["from"]),
      actor_username: user_username(message["from"]),
      chat_id: chat_id(message["chat"]),
      chat_title: chat_title(message["chat"]),
      chat_type: chat_type(message["chat"]),
      message_text: message["text"],
      status_from: nil,
      status_to: nil,
      update_type: update_type(update)
    }
  end

  defp user_name(nil), do: nil

  defp user_name(user) do
    [user["first_name"], user["last_name"]]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  defp user_username(nil), do: nil
  defp user_username(user), do: user["username"]

  defp member_status(nil), do: nil
  defp member_status(chat_member), do: chat_member["status"]

  defp update_type(update) do
    update
    |> Map.keys()
    |> Enum.reject(&(&1 == "update_id"))
    |> List.first()
    |> Kernel.||("unknown")
  end

  defp bot_token do
    System.fetch_env!("TELEGRAM_BOT_TOKEN")
  end

  defp chat_member_from_response({:ok, %Req.Response{status: 200, body: body}}) do
    case body do
      %{"ok" => true, "result" => chat_member} -> {:ok, chat_member}
      %{"ok" => false, "description" => description} -> {:error, {:telegram_error, description}}
      %{"ok" => false} -> {:error, :telegram_error}
      body -> {:error, {:unexpected_response, body}}
    end
  end

  defp chat_member_from_response({:ok, %Req.Response{status: status, body: body}}) do
    {:error, {:http_error, status, body}}
  end

  defp chat_member_from_response({:error, error}) do
    {:error, error}
  end
end
