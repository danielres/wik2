defmodule QblogWeb.Superadmin.TelegramBotUpdatesLive do
  use QblogWeb, :live_view

  alias Qblog.Access

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_bot_updates(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} scope={@current_scope}>
      <Layouts.container>
        <div class="space-y-6">
          <div class="space-y-1">
            <h1 class="text-2xl font-[100]">Telegram bot updates</h1>
            <p class="opacity-70">
              Raw Telegram webhook updates, newest first.
            </p>
          </div>

          <div :if={@bot_updates == []} class="opacity-70" data-testid="telegram-bot-updates-empty">
            No bot updates received yet.
          </div>

          <div
            :for={bot_update <- @bot_updates}
            class={[
              "card bg-base-200 shadow",
              "border border-base-300"
            ]}
            data-testid={"telegram-bot-update-#{bot_update.update_id}"}
          >
            <div class="card-body gap-4">
              <div class="flex flex-wrap items-center gap-2">
                <span class="badge badge-neutral">#{bot_update.update_id}</span>
                <span class="badge badge-accent">{bot_update.update_type}</span>
                <span class="text-sm opacity-70">
                  {Calendar.strftime(bot_update.inserted_at, "%Y-%m-%d %H:%M:%S UTC")}
                </span>
              </div>

              <pre class={[
                "max-h-96 overflow-auto rounded-box",
                "bg-base-300 p-4 text-xs"
              ]}><code>{format_payload(bot_update.payload)}</code></pre>
            </div>
          </div>
        </div>
      </Layouts.container>
    </Layouts.app>
    """
  end

  defp assign_bot_updates(socket) do
    {:ok, bot_updates} = Access.telegram_list_bot_updates(socket.assigns.current_user)

    assign(socket, :bot_updates, bot_updates)
  end

  defp format_payload(payload) do
    Jason.encode!(payload, pretty: true)
  end
end
