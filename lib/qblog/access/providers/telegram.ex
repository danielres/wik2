defmodule Qblog.Access.Providers.Telegram do
  alias Assent.Strategy.Telegram, as: AssentTelegram

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

  def creator?(%{"status" => "creator"}), do: true
  def creator?(_chat_member), do: false

  def active_member?(%{"status" => status}), do: status in @active_member_statuses
  def active_member?(_chat_member), do: false

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
