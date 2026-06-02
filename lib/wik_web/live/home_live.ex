defmodule WikWeb.HomeLive do
  use WikWeb, :live_view

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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app context={@context} flash={@flash} scope={@current_scope}>
      <Layouts.container>
        <UI.page_head></UI.page_head>

        <div class="grid sm:grid-cols-2 gap-8">
          <UI.page_blocks>
            <:title>Your spaces</:title>

            <:actions>
              <UI.button_plus
                :if={Ash.can?({Space, :create}, @current_scope)}
                data-testid="create-space-start"
                phx-click="create_space_start"
              />
            </:actions>

            <:body>
              <Components.Space.list spaces={@spaces} />

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
            </:body>
          </UI.page_blocks>
          <UI.page_blocks>
            <:title>All your events</:title>

            <:actions>
              <Components.CalendarFeed.aggregate_subscribe_button scope={@current_scope} />
            </:actions>

            <:body>
              <Components.Event.list
                current_scope={@current_scope}
                items={@event_items}
                user_tz={@active_tz}
              />
            </:body>
          </UI.page_blocks>
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

    socket
    |> assign(event_items: list_aggregate_event_items(scope))
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
      entries
      |> Enum.map(fn entry -> List.first(entry.publications) end)
      |> with_author_memberships()
    else
      err ->
        Log.scoped_error(scope, err, "list_aggregate_feed_events failed")
        []
    end
  end

  defp with_author_memberships(publications) do
    publications
    |> author_memberships_by_space_and_user()
    |> then(fn memberships_by_space_and_user ->
      Enum.map(publications, fn publication ->
        TimelinePresenter.internal_item(
          publication,
          Map.get(memberships_by_space_and_user, {
            publication.space.id,
            publication.event.author.id
          })
        )
      end)
    end)
  end

  defp author_memberships_by_space_and_user(publications) do
    publications
    |> Enum.group_by(& &1.space.id)
    |> Enum.reduce(%{}, fn {_space_id, space_publications}, acc ->
      space = List.first(space_publications).space
      user_ids = Enum.map(space_publications, & &1.event.author.id) |> Enum.uniq()

      case Accounts.list_memberships_by_user_id(space.id, user_ids) do
        {:ok, memberships_by_user_id} ->
          Enum.reduce(memberships_by_user_id, acc, fn {user_id, membership}, space_acc ->
            Map.put(space_acc, {space.id, user_id}, membership)
          end)

        {:error, _error} ->
          acc
      end
    end)
  end
end
