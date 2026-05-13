defmodule WikWeb.Auth.TelegramSourcesLive do
  use WikWeb, :live_view

  alias AshPhoenix.Form
  alias Wik.Access
  alias Wik.Accounts
  alias Wik.Accounts.Group
  alias WikWeb.Components

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:create_group_form, nil)
     |> assign(:create_group_source, nil)
     |> assign_claim_form_state()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app context={@context} flash={@flash} scope={@current_scope}>
      <Layouts.container>
        <div class="space-y-4" data-testid="telegram-sources-page">
          <.claimable_sources
            claimable_sources={@context.claimable_sources}
            owned_groups={@owned_groups}
            claim_existing_group_form={@claim_existing_group_form}
            create_group_form={@create_group_form}
            create_group_source={@create_group_source}
            owned_group_options={@owned_group_options}
          />
        </div>
      </Layouts.container>
    </Layouts.app>
    """
  end

  attr :claimable_sources, :list, required: true
  attr :owned_groups, :list, required: true
  attr :claim_existing_group_form, :map, required: true
  attr :create_group_form, :any, default: nil
  attr :create_group_source, :map, default: nil
  attr :owned_group_options, :list, required: true

  def claimable_sources(assigns) do
    ~H"""
    <div :if={@claimable_sources == []} class="opacity-70" data-testid="telegram-sources-empty">
      No claimable Telegram groups found.
    </div>

    <div :if={@claimable_sources != []} class="">
      <div class="space-y-8">
        <div
          :for={source <- @claimable_sources}
          class={[
            "card bg-base-200 shadow border-2 border-accent/50"
          ]}
        >
          <div class="card-body space-y-1">
            <div class="grid justify-center gap-4">
              <h2 class={[
                "text-lg font-bold text-center",
                "flex items-center gap-2 justify-center"
              ]}>
                <.icon name="hero-check-circle-mini" class="w-6 h-6 text-accent" />
                <span>Telegram group detected</span>
              </h2>

              <div class="bg-accent/70 p-4 border border-base-100 rounded-box space-y-4 max-w-md mx-auto">
                <div class="space-y-2 flex flex-col items-center">
                  <div class="font-bold">{source.title}</div>
                  <div class="badge badge-xs bg-base-300 opacity-40">
                    id: {source.provider_source_id}
                  </div>
                </div>
              </div>
            </div>

            <div class={[
              "bg-base-100 px-2 py-4 rounded-box",
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
                phx-click="claim_source_with_new_group_start"
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

    <Components.Modal.render
      :if={@create_group_form != nil and @create_group_source != nil}
      cancel="claim_source_with_new_group_cancel"
      cancel_testid="telegram-create-group-cancel"
      open?={true}
      testid="telegram-create-group-dialog"
    >
      <:title>Create group</:title>

      <div class="mb-4 rounded-box border border-base-300 bg-base-100/70 px-4 py-3 text-sm opacity-80">
        Telegram group: {@create_group_source.title}
      </div>

      <Components.Group.form
        class="flex-1"
        event_validate="claim_source_with_new_group_validate"
        event_submit="claim_source_with_new_group_submit"
        form={@create_group_form}
      />
    </Components.Modal.render>
    """
  end

  @impl true
  def handle_event("claim_source_with_new_group_start", %{"source_id" => source_id}, socket) do
    case Enum.find(socket.assigns.context.claimable_sources, &(&1.id == source_id)) do
      nil ->
        {:noreply, socket}

      source ->
        params = %{
          "description" => "Created from Telegram group #{source.title}",
          "name" => source.title
        }

        form =
          socket.assigns.current_scope
          |> init_group_form()
          |> Form.validate(params)
          |> to_form()

        {:noreply,
         socket
         |> assign(:create_group_form, form)
         |> assign(:create_group_source, source)}
    end
  end

  @impl true
  def handle_event("claim_source_with_new_group_cancel", _params, socket) do
    {:noreply,
     socket
     |> assign(:create_group_form, nil)
     |> assign(:create_group_source, nil)}
  end

  @impl true
  def handle_event("claim_source_with_new_group_validate", %{"form" => params}, socket) do
    {:noreply,
     assign(
       socket,
       :create_group_form,
       socket.assigns.create_group_form
       |> Form.validate(group_params(params))
       |> to_form()
     )}
  end

  @impl true
  def handle_event("claim_source_with_new_group_submit", %{"form" => params}, socket) do
    case Access.telegram_claim_source_with_new_group(
           socket.assigns.create_group_source.id,
           group_params(params),
           socket.assigns.current_user
         ) do
      {:ok, {group, _source}} ->
        {:noreply, socket |> push_navigate(to: ~p"/#{group.slug}")}

      {:error, error} ->
        form =
          socket.assigns.create_group_form
          |> Form.validate(group_params(params))
          |> Form.add_error(error)
          |> to_form()

        {:noreply,
         socket
         |> assign(:create_group_form, form)}
    end
  end

  @impl true
  def handle_event(
        "claim_source_with_existing_group",
        %{"claim" => %{"group_id" => group_id}, "source_id" => source_id},
        socket
      ) do
    case Access.telegram_claim_source_with_existing_group(
           source_id,
           group_id,
           socket.assigns.current_user
         ) do
      {:ok, {group, _source}} ->
        {:noreply, socket |> push_navigate(to: ~p"/#{group.slug}")}

      {:error, _error} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not claim Telegram group")}
    end
  end

  defp assign_claim_form_state(socket) do
    {:ok, owned_groups} = Accounts.list_owned_groups(socket.assigns.current_user)

    socket
    |> assign(:claim_existing_group_form, to_form(%{}, as: :claim))
    |> assign(:owned_group_options, Enum.map(owned_groups, &{&1.name, &1.id}))
    |> assign(:owned_groups, owned_groups)
  end

  defp init_group_form(scope) do
    Group
    |> Form.for_create(:create, scope: scope)
  end

  defp group_params(%{"name" => name} = params) do
    Map.put(params, "slug", Utils.Slugify.generate(name))
  end

  defp group_params(params), do: params
end
