defmodule QblogWeb.Components.Telegram.Widgets do
  use QblogWeb, :html

  attr :class, :string, default: nil
  attr :request_access, :string, default: "write"
  attr :size, :string, default: "large", values: ~w(small medium large)

  def login(assigns) do
    assigns = assign(assigns, :bot_username, System.fetch_env!("TELEGRAM_BOT_USERNAME"))

    ~H"""
    <div
      id="telegram-login"
      class={@class}
      data-bot-username={@bot_username}
      data-request-access={@request_access}
      data-size={@size}
      phx-hook="TelegramLogin"
      phx-update="ignore"
    />
    """
  end
end
