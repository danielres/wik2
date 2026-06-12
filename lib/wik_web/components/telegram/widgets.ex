defmodule WikWeb.Components.Telegram.Widgets do
  use WikWeb, :html

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

  attr :class, :string, default: nil
  attr :request_access, :string, default: "write"
  attr :size, :string, default: "large", values: ~w(small medium large)

  def login_custom(assigns) do
    assigns = assign(assigns, :bot_username, System.fetch_env!("TELEGRAM_BOT_USERNAME"))

    ~H"""
    <div class={[
      "stacked",
      "opacity-90 hover:opacity-100 transition overflow-hidden justify-center items-center"
    ]}>
      <div class="btn btn-primary gap-2">
        <svg xmlns="http://www.w3.org/2000/svg" class="size-5" viewBox="0 0 24 24">
          <path d="M0 0h24v24H0z" fill="none" />
          <path
            fill="currentColor"
            d="M2.148 11.81q7.87-3.429 10.497-4.522c4.999-2.079 6.037-2.44 6.714-2.452c.15-.003.482.034.698.21c.182.147.232.347.256.487s.054.459.03.708c-.27 2.847-1.443 9.754-2.04 12.942c-.252 1.348-.748 1.8-1.23 1.845c-1.045.096-1.838-.69-2.85-1.354c-1.585-1.039-2.48-1.686-4.018-2.699c-1.777-1.171-.625-1.815.388-2.867c.265-.275 4.87-4.464 4.96-4.844c.01-.048.021-.225-.084-.318c-.105-.094-.26-.062-.373-.036q-.239.054-7.592 5.018q-1.079.74-1.952.721c-.643-.014-1.88-.363-2.798-.662c-1.128-.367-2.024-.56-1.946-1.183q.061-.486 1.34-.994"
          />
        </svg>
        Sign in with Telegram
      </div>

      <div
        id="telegram-login"
        class={[@class, "opacity-0"]}
        data-bot-username={@bot_username}
        data-request-access={@request_access}
        data-size={@size}
        phx-hook="TelegramLogin"
        phx-update="ignore"
      />
    </div>
    """
  end
end
