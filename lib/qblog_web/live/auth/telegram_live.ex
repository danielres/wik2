defmodule QblogWeb.Auth.TelegramLive do
  use QblogWeb, :live_view

  alias Qblog.Access
  alias Qblog.Scope

  on_mount {QblogWeb.LiveUserAuth, :current_user}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign_claimable_sources()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} scope={@current_scope}>
      <Layouts.container>
        <h1 class="text-2xl font-[100]">Login with Telegram</h1>

        <QblogWeb.Components.Telegram.Widgets.login :if={@current_user == nil} />

        <div :if={@current_user != nil} class="space-y-4">
          <div :if={@claimable_sources == []} class="opacity-70">
            No claimable Telegram groups found.
          </div>

          <div :if={@claimable_sources != []} class="card bg-base-200">
            <div class="card-body">
              <h2 class="card-title">Claim Telegram group</h2>

              <div class="space-y-2">
                <div
                  :for={source <- @claimable_sources}
                  class={[
                    "flex items-center justify-between gap-4",
                    "rounded bg-base-100 p-3"
                  ]}
                >
                  <div>
                    <div class="font-bold">{source.title}</div>
                    <div class="text-xs opacity-60">{source.provider_source_id}</div>
                  </div>

                  <button
                    class="btn btn-primary btn-sm"
                    phx-click="claim_source_with_new_group"
                    phx-value-source_id={source.id}
                  >
                    Create group
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </Layouts.container>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("claim_source_with_new_group", %{"source_id" => source_id}, socket) do
    case Access.claim_telegram_source_with_new_group(source_id, socket.assigns.current_user) do
      {:ok, {group, _source}} ->
        {:noreply, socket |> push_navigate(to: ~p"/#{group.name}")}

      {:error, _error} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not claim Telegram group")
         |> assign_claimable_sources()}
    end
  end

  defp assign_claimable_sources(socket) do
    current_user = socket.assigns[:current_user]
    current_scope = %Scope{actor: current_user, tenant: nil}

    claimable_sources =
      case current_user do
        nil -> []
        current_user -> Access.list_claimable_telegram_sources(current_user)
      end

    socket
    |> assign(:claimable_sources, claimable_sources)
    |> assign(:current_scope, current_scope)
  end
end
