defmodule WikWeb.HomeLive do
  use WikWeb, :live_view

  require Ash.Query

  alias AshPhoenix.Form
  alias Wik.Accounts
  alias Wik.Accounts.Space
  alias Wik.Events
  alias WikWeb.Components
  alias WikWeb.Components.UI
  alias WikWeb.EventsLive.TimelinePresenter
  alias Utils.Log

  on_mount {WikWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:create_space_modal_open?, false)
     |> assign_spaces_and_form()}
  end

  slot :body, required: true
  slot :title, required: false
  slot :actions, required: false

  def page_blocks(assigns) do
    ~H"""
    <section>
      <div :if={@title != []} class="flex items-center justify-between mb-1">
        <h2 class="text-lg">
          {render_slot(@title)}
        </h2>

        <div :if={@actions != []}>
          {render_slot(@actions)}
        </div>
      </div>

      <div class="space-y-2">
        <div :for={body <- @body} class="card bg-base-200 h-min">
          <div class="card-body p-2">
            {render_slot(body)}
          </div>
        </div>
      </div>
    </section>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app context={@context} flash={@flash} scope={@current_scope}>
      <Layouts.container>
        <div class="grid sm:grid-cols-2 gap-8 my-4">
          <section>
            <UI.panel_title class="flex justify-between items-end">
              <span>Your spaces</span>
              <UI.button_plus
                :if={Ash.can?({Space, :create}, @current_scope)}
                data-testid="create-space-start"
                phx-click="create_space_start"
              />
            </UI.panel_title>

            <div class={[
              "autogrid",
              "gap-2",
              "auto-rows-[minmax(0,1fr)]",
              "[--autogrid-min:9rem]"
            ]}>
              <.link
                :for={space <- @spaces}
                class={[
                  "bg-base-content/5",
                  "opacity-80 hover:opacity-100 transition",
                  "text-xs font-bold",
                  "leading-none",
                  "cursor-pointer",
                  "",
                  "p-4"
                ]}
                navigate={~p"/#{space.slug}/wiki"}
              >
                {space.name}
              </.link>
            </div>

            <span :if={@spaces == []} class="opacity-70">
              You are not a member of any spaces yet.
            </span>

            <Components.Modal.render
              :if={@create_space_modal_open?}
              cancel="create_space_cancel"
              cancel_testid="create-space-cancel"
              open?={true}
              testid="create-space-dialog"
            >
              <:title>Create space</:title>

              <Components.Space.form
                :if={Ash.can?({Space, :create}, @current_scope)}
                class="flex-1"
                event_validate="validate"
                event_submit="submit"
                form={@form}
              />
            </Components.Modal.render>
          </section>

          <section class={[
            "lg:border-l",
            "lg:pl-8",
            "border-base-content/8"
          ]}>
            <UI.panel_title class="flex justify-between items-end">
              <span>Events</span>
              <Components.CalendarFeed.aggregate_subscribe_button scope={@current_scope} />
            </UI.panel_title>

            <div style="--top: 0rem">
              <Components.Event.grouped_timeline
                current_scope={@current_scope}
                grouped_items={@grouped_event_items}
                source_label_mode={:aggregate}
                user_tz={@active_tz}
              />
            </div>
          </section>
        </div>
      </Layouts.container>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, socket |> assign(form: socket.assigns.form |> Form.validate(space_params(params)))}
  end

  def handle_event("create_space_start", _params, socket) do
    current_scope = socket.assigns.current_scope

    socket =
      socket
      |> assign(:create_space_modal_open?, true)
      |> assign(:form, init_form(current_scope))

    {:noreply, socket}
  end

  def handle_event("create_space_cancel", _params, socket) do
    current_scope = socket.assigns.current_scope

    socket =
      socket
      |> assign(:create_space_modal_open?, false)
      |> assign(:form, init_form(current_scope))

    {:noreply, socket}
  end

  def handle_event("submit", %{"form" => params}, socket) do
    case socket.assigns.form |> Form.submit(params: space_params(params)) do
      {:ok, _space} ->
        socket =
          socket
          |> assign_spaces_and_form()
          |> assign(:create_space_modal_open?, false)

        {:noreply, socket}

      {:error, form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Something went wrong")
         |> assign(form: form)}
    end
  end

  defp assign_spaces_and_form(socket) do
    scope = socket.assigns.current_scope
    event_items = list_aggregate_event_items(scope)

    socket
    |> assign(event_items: event_items)
    |> assign(grouped_event_items: TimelinePresenter.grouped_timeline_items(event_items))
    |> assign(spaces: scope |> list_spaces())
    |> assign(form: scope |> init_form())
  end

  defp init_form(scope) do
    Space |> Form.for_create(:create, scope: scope) |> to_form()
  end

  defp space_params(%{"name" => name} = params) do
    Map.put(params, "slug", Utils.Slugify.generate(name))
  end

  defp space_params(params), do: params

  defp list_spaces(nil), do: []

  defp list_spaces(scope) do
    with {:ok, spaces} <- Accounts.list_spaces(scope: scope) do
      spaces
    else
      err ->
        Log.scoped_error(scope, err, "list_spaces failed")
        []
    end
  end

  defp list_aggregate_event_items(nil), do: []

  defp list_aggregate_event_items(scope) do
    with {:ok, entries} <- Events.list_aggregate_feed_events(scope.actor) do
      TimelinePresenter.aggregate_items(entries, scope.actor, upcoming?: true)
    else
      err ->
        Log.scoped_error(scope, err, "list_aggregate_event_items failed")
        []
    end
  end
end
