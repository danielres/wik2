defmodule WikWeb.Superadmin.TelegramBotUpdatesLive do
  use WikWeb, :live_view
  use Cinder.UrlSync

  alias Wik.Access
  alias Wik.Access.Telegram.Bot.Update, as: BotUpdate
  alias WikWeb.Components.Modal

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:bot_updates_query, bot_updates_query())
     |> assign(:selected_bot_update, nil)}
  end

  @impl true
  def handle_params(params, uri, socket) do
    socket = Cinder.UrlSync.handle_params(params, uri, socket)

    {:noreply, socket}
  end

  @impl true
  def handle_event("show_bot_update", %{"id" => id}, socket) do
    {:ok, bot_update} = Access.telegram_get_bot_update(id, socket.assigns.current_user)

    {:noreply, assign(socket, :selected_bot_update, bot_update)}
  end

  @impl true
  def handle_event("hide_bot_update", _params, socket) do
    {:noreply, assign(socket, :selected_bot_update, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app context={@context} flash={@flash} scope={@current_scope}>
      <Layouts.superadmin scope={@current_scope}>
        <div class="space-y-6">
          <div class="space-y-1">
            <h1 class="text-2xl font-[100]">Telegram bot updates</h1>
            <p class="opacity-70">
              Telegram webhook updates, newest first. Click a row to inspect the raw JSON.
            </p>
          </div>

          <Cinder.collection
            actor={@current_user}
            click={fn bot_update -> JS.push("show_bot_update", value: %{id: bot_update.id}) end}
            empty_message="No bot updates received yet."
            id="telegram-bot-updates"
            page_size={[default: 25, options: [10, 25, 50, 100]]}
            query={@bot_updates_query}
            show_filters={:toggle_open}
            sort_mode="exclusive"
            theme={WikWeb.Cinder.Themes.Dense}
            url_state={@url_state}
          >
            <:col :let={bot_update} field="update_id" label="Update" sort>
              <span
                class="badge badge-xs badge-neutral"
                data-testid={"telegram-bot-update-#{bot_update.update_id}"}
              >
                #{bot_update.update_id}
              </span>
            </:col>

            <:col :let={bot_update} field="summary__update_type" label="Type" filter sort search>
              <span
                class="badge badge-sm badge-neutral"
                data-testid={"telegram-bot-update-type-#{bot_update.update_id}"}
              >
                {bot_update.summary.update_type}
              </span>
            </:col>

            <:col :let={bot_update} field="summary__chat_title" label="Chat" filter search>
              <span data-testid={"telegram-bot-update-chat-title-#{bot_update.update_id}"}>
                {bot_update.summary.chat_title |> value_or_dash()}
              </span>
            </:col>

            <:col :let={bot_update} field="summary__chat_type" label="Chat type" filter sort>
              {bot_update.summary.chat_type |> value_or_dash()}
            </:col>

            <:col :let={bot_update} field="summary__actor_username" label="Actor" filter search>
              {bot_update.summary |> actor_label()}
            </:col>

            <:col :let={bot_update} field="summary__message_text" label="Message" filter search>
              <span class="line-clamp-2">{bot_update.summary.message_text |> value_or_dash()}</span>
            </:col>

            <:col :let={bot_update} field="summary__status_to" label="Status" filter sort>
              <div class="flex items-center gap-1">
                <span>{bot_update.summary.status_from |> value_or_dash()}</span>
                <.icon
                  :if={bot_update.summary.status_from != nil or bot_update.summary.status_to != nil}
                  name="hero-arrow-right-micro"
                />
                <span>{bot_update.summary.status_to |> value_or_dash()}</span>
              </div>
            </:col>

            <:col :let={bot_update} field="inserted_at" label="Received" sort>
              <span class="whitespace-nowrap">
                {Calendar.strftime(bot_update.inserted_at, "%Y-%m-%d %H:%M:%S UTC")}
              </span>
            </:col>
          </Cinder.collection>

          <Modal.render
            :if={@selected_bot_update}
            cancel="hide_bot_update"
            cancel_testid="telegram-bot-update-cancel"
            open?={true}
            testid="telegram-bot-update-dialog"
          >
            <:title>
              Telegram update #{@selected_bot_update.update_id}
            </:title>

            <pre class={[
              "max-h-[70dvh] overflow-auto rounded-box",
              "bg-base-300 p-4 text-xs"
            ]}><code>{format_payload(@selected_bot_update.payload)}</code></pre>
          </Modal.render>
        </div>
      </Layouts.superadmin>
    </Layouts.app>
    """
  end

  defp bot_updates_query do
    BotUpdate
    |> Ash.Query.sort(inserted_at: :desc, update_id: :desc)
  end

  defp format_payload(payload) do
    Jason.encode!(payload, pretty: true)
  end

  defp actor_label(summary) do
    (summary.actor_username || summary.actor_name) |> value_or_dash()
  end

  defp value_or_dash(nil), do: "-"
  defp value_or_dash(""), do: "-"
  defp value_or_dash(value), do: value
end
