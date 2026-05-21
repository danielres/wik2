defmodule WikWeb.Auth.TelegramSourcesLive do
  use WikWeb, :live_view

  alias AshPhoenix.Form
  alias Wik.Access
  alias Wik.Accounts
  alias Wik.Accounts.Space
  alias WikWeb.Components

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:create_space_form, nil)
     |> assign(:create_space_source, nil)
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
            owned_spaces={@owned_spaces}
            claim_existing_space_form={@claim_existing_space_form}
            create_space_form={@create_space_form}
            create_space_source={@create_space_source}
            owned_space_options={@owned_space_options}
          />
        </div>
      </Layouts.container>
    </Layouts.app>
    """
  end

  attr :claimable_sources, :list, required: true
  attr :owned_spaces, :list, required: true
  attr :claim_existing_space_form, :map, required: true
  attr :create_space_form, :any, default: nil
  attr :create_space_source, :map, default: nil
  attr :owned_space_options, :list, required: true

  def claimable_sources(assigns) do
    ~H"""
    <div :if={@claimable_sources == []} class="opacity-70" data-testid="telegram-sources-empty">
      No claimable Telegram spaces found.
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
                <span>Telegram space detected</span>
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
                :if={@owned_spaces != []}
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
                phx-click="claim_source_with_new_space_start"
                phx-value-source_id={source.id}
              >
                Create new space
              </button>
            </div>

            <div
              :if={@owned_spaces != []}
              class={[
                "bg-base-100 px-4 py-8 rounded-box",
                "flex flex-col items-center gap-4"
              ]}
            >
              <span class="badge badge-neutral h-8 font-bold">Option 2</span>
              <.form
                for={@claim_existing_space_form}
                id={"claim-source-#{source.id}-existing-space-form"}
                class="contents"
                phx-submit="claim_source_with_existing_space"
              >
                <p class="opacity-70">
                  Allow members to access:
                </p>

                <input name="source_id" type="hidden" value={source.id} />

                <.input
                  field={@claim_existing_space_form[:space_id]}
                  id={"claim-source-#{source.id}-space-id"}
                  options={@owned_space_options}
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
      :if={@create_space_form != nil and @create_space_source != nil}
      cancel="claim_source_with_new_space_cancel"
      cancel_testid="telegram-create-space-cancel"
      open?={true}
      testid="telegram-create-space-dialog"
    >
      <:title>Create space</:title>

      <div class="mb-4 rounded-box border border-base-300 bg-base-100/70 px-4 py-3 text-sm opacity-80">
        Telegram space: {@create_space_source.title}
      </div>

      <Components.Space.form
        class="flex-1"
        event_validate="claim_source_with_new_space_validate"
        event_submit="claim_source_with_new_space_submit"
        form={@create_space_form}
      />
    </Components.Modal.render>
    """
  end

  @impl true
  def handle_event("claim_source_with_new_space_start", %{"source_id" => source_id}, socket) do
    case Enum.find(socket.assigns.context.claimable_sources, &(&1.id == source_id)) do
      nil ->
        {:noreply, socket}

      source ->
        params = %{
          "description" => "Created from Telegram space #{source.title}",
          "name" => source.title
        }

        form =
          socket.assigns.current_scope
          |> init_space_form()
          |> Form.validate(space_params(params))
          |> to_form()

        {:noreply,
         socket
         |> assign(:create_space_form, form)
         |> assign(:create_space_source, source)}
    end
  end

  @impl true
  def handle_event("claim_source_with_new_space_cancel", _params, socket) do
    {:noreply,
     socket
     |> assign(:create_space_form, nil)
     |> assign(:create_space_source, nil)}
  end

  @impl true
  def handle_event("claim_source_with_new_space_validate", %{"form" => params}, socket) do
    {:noreply,
     assign(
       socket,
       :create_space_form,
       socket.assigns.create_space_form
       |> Form.validate(space_params(params))
       |> to_form()
     )}
  end

  @impl true
  def handle_event("claim_source_with_new_space_submit", %{"form" => params}, socket) do
    case Access.telegram_claim_source_with_new_space(
           socket.assigns.create_space_source.id,
           space_params(params),
           socket.assigns.current_user
         ) do
      {:ok, {space, _source}} ->
        {:noreply, socket |> push_navigate(to: ~p"/#{space.slug}")}

      {:error, error} ->
        form =
          socket.assigns.create_space_form
          |> Form.validate(space_params(params))
          |> Form.add_error(error)
          |> to_form()

        {:noreply,
         socket
         |> assign(:create_space_form, form)}
    end
  end

  @impl true
  def handle_event(
        "claim_source_with_existing_space",
        %{"claim" => %{"space_id" => space_id}, "source_id" => source_id},
        socket
      ) do
    case Access.telegram_claim_source_with_existing_space(
           source_id,
           space_id,
           socket.assigns.current_user
         ) do
      {:ok, {space, _source}} ->
        {:noreply, socket |> push_navigate(to: ~p"/#{space.slug}")}

      {:error, _error} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not claim Telegram space")}
    end
  end

  defp assign_claim_form_state(socket) do
    {:ok, owned_spaces} = Accounts.list_owned_spaces(socket.assigns.current_user)

    socket
    |> assign(:claim_existing_space_form, to_form(%{}, as: :claim))
    |> assign(:owned_space_options, Enum.map(owned_spaces, &{&1.name, &1.id}))
    |> assign(:owned_spaces, owned_spaces)
  end

  defp init_space_form(scope) do
    Space
    |> Form.for_create(:create, scope: scope)
  end

  defp space_params(%{"name" => name} = params) do
    Map.put(params, "slug", Utils.Slugify.generate(name))
  end

  defp space_params(params), do: params
end
