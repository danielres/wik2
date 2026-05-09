defmodule WikWeb.HomeLive do
  use WikWeb, :live_view

  alias AshPhoenix.Form
  alias Wik.Accounts
  alias Wik.Accounts.Group
  alias Wik.Events
  alias WikWeb.Components
  alias WikWeb.Components.UI
  alias Utils.Log

  on_mount {WikWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:create_group_modal_open?, false)
     |> assign_groups_and_form()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app context={@context} flash={@flash} scope={@current_scope}>
      <Layouts.container>
        <div class="grid sm:grid-cols-2 gap-8">
          <section>
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-2xl font-[100]">Your groups</h2>
              <UI.button_plus
                :if={Ash.can?({Group, :create}, @current_scope)}
                data-testid="create-group-start"
                phx-click="create_group_start"
              />
            </div>

            <div class="flex-1">
              <Components.Group.list groups={@groups} />

              <Components.Modal.render
                :if={@create_group_modal_open?}
                cancel="create_group_cancel"
                cancel_testid="create-group-cancel"
                open?={true}
                testid="create-group-dialog"
              >
                <:title>Create group</:title>

                <Components.Group.form
                  :if={Ash.can?({Group, :create}, @current_scope)}
                  class="flex-1"
                  event_validate="validate"
                  event_submit="submit"
                  form={@form}
                />
              </Components.Modal.render>
            </div>
          </section>

          <section>
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-2xl font-[100]">All your events</h2>
              <Components.CalendarFeed.aggregate_subscribe_button scope={@current_scope} />
            </div>

            <Components.Event.list
              current_scope={@current_scope}
              event_publications={@event_publications}
              user_tz={@active_tz}
            />
          </section>
        </div>
      </Layouts.container>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, socket |> assign(form: socket.assigns.form |> Form.validate(params))}
  end

  def handle_event("create_group_start", _params, socket) do
    current_scope = socket.assigns.current_scope

    socket =
      socket
      |> assign(:create_group_modal_open?, true)
      |> assign(:form, init_form(current_scope))

    {:noreply, socket}
  end

  def handle_event("create_group_cancel", _params, socket) do
    current_scope = socket.assigns.current_scope

    socket =
      socket
      |> assign(:create_group_modal_open?, false)
      |> assign(:form, init_form(current_scope))

    {:noreply, socket}
  end

  def handle_event("submit", %{"form" => params}, socket) do
    case socket.assigns.form |> Form.submit(params: params) do
      {:ok, _group} ->
        socket =
          socket
          |> assign_groups_and_form()
          |> assign(:create_group_modal_open?, false)

        {:noreply, socket}

      {:error, form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Something went wrong")
         |> assign(form: form)}
    end
  end

  defp assign_groups_and_form(socket) do
    scope = socket.assigns.current_scope

    socket
    |> assign(event_publications: list_aggregate_event_publications(scope))
    |> assign(groups: scope |> list_groups())
    |> assign(form: scope |> init_form())
  end

  defp init_form(scope) do
    Group |> Form.for_create(:create, scope: scope) |> to_form()
  end

  defp list_groups(nil), do: []

  defp list_groups(scope) do
    with {:ok, groups} <- Accounts.list_groups(scope: scope) do
      groups
    else
      err ->
        Log.scoped_error(scope, err, "list_groups failed")
        []
    end
  end

  defp list_aggregate_event_publications(nil), do: []

  defp list_aggregate_event_publications(scope) do
    with {:ok, entries} <- Events.list_aggregate_feed_events(scope.actor) do
      Enum.map(entries, fn entry -> List.first(entry.publications) end)
    else
      err ->
        Log.scoped_error(scope, err, "list_aggregate_feed_events failed")
        []
    end
  end
end
