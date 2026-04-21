defmodule QblogWeb.Auth.TelegramLive do
  use QblogWeb, :live_view

  alias Qblog.Access
  alias Qblog.Accounts
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

          <div :if={@claimable_sources != []} class="">
            <div class="space-y-2">
              <div
                :for={source <- @claimable_sources}
                class={[
                  "card bg-base-200 shadow"
                ]}
              >
                <div class="card-body space-y-6">
                  <div class="grid justify-center gap-4">
                    <h2 class="text-lg font-bold text-center">
                      Telegram group detected
                    </h2>

                    <div class="bg-base-300 p-4 border border-base-100 rounded-box space-y-4 max-w-sm mx-auto">
                      <div class="space-y-2 flex flex-col items-center">
                        <div class="font-bold">{source.title}</div>
                        <div class="badge badge-xs badge-neutral bg-base-100">
                          id: {source.provider_source_id}
                        </div>
                      </div>
                    </div>
                  </div>

                  <div class={[
                    "bg-base-100 px-4 py-8 rounded-box",
                    "flex flex-col items-center gap-4"
                  ]}>
                    <span
                      :if={@owned_groups != []}
                      class="badge badge-neutral h-8 font-bold"
                    >
                      Option 1
                    </span>

                    <ul class="list opacity-70 text-center">
                      <li>Create a new space.</li>
                      <li><.icon name="hero-plus-micro" /></li>
                      <li>
                        Allow members to access the new space.
                      </li>
                    </ul>

                    <button
                      class="btn btn-accent btn-sm"
                      phx-click="claim_source_with_new_group"
                      phx-value-source_id={source.id}
                    >
                      Create new space
                    </button>
                  </div>

                  <div
                    :if={@owned_groups != []}
                    class={[
                      "bg-base-100 px-4 py-8 rounded-box",
                      "flex flex-col items-center gap-4"
                    ]}
                  >
                    <span class="badge badge-neutral h-8 font-bold">Option 2</span>
                    <.form
                      for={@claim_existing_group_form}
                      id={"claim-source-#{source.id}-existing-group-form"}
                      class="contents"
                      phx-submit="claim_source_with_existing_group"
                    >
                      <p class="opacity-70">
                        Allow members to access:
                      </p>

                      <input name="source_id" type="hidden" value={source.id} />

                      <.input
                        field={@claim_existing_group_form[:group_id]}
                        id={"claim-source-#{source.id}-group-id"}
                        options={@owned_group_options}
                        type="select"
                        class="select select-sm bg-base-200"
                      />

                      <button class="btn btn-accent btn-sm" type="submit">
                        Allow access
                      </button>
                    </.form>
                  </div>
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

  @impl true
  def handle_event(
        "claim_source_with_existing_group",
        %{"claim" => %{"group_id" => group_id}, "source_id" => source_id},
        socket
      ) do
    case Access.claim_telegram_source_with_existing_group(
           source_id,
           group_id,
           socket.assigns.current_user
         ) do
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

    {claimable_sources, owned_groups} =
      if current_user == nil do
        {[], []}
      else
        {:ok, owned_groups} = Accounts.list_owned_groups(current_user)
        {Access.list_claimable_telegram_sources(current_user), owned_groups}
      end

    socket
    |> assign(:claim_existing_group_form, to_form(%{}, as: :claim))
    |> assign(:claimable_sources, claimable_sources)
    |> assign(:current_scope, current_scope)
    |> assign(:owned_group_options, Enum.map(owned_groups, &{&1.name, &1.id}))
    |> assign(:owned_groups, owned_groups)
  end
end
