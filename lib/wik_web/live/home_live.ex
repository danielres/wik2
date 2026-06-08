defmodule WikWeb.HomeLive do
  use WikWeb, :live_view

  require Ash.Query

  alias AshPhoenix.Form
  alias Wik.Accounts
  alias Wik.Accounts.Space
  alias Wik.Events
  alias Wik.Events.EventParticipation
  alias Wik.Events.ExternalCalendar
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
    with {:ok, entries} <- Events.list_aggregate_feed_events(scope.actor),
         {:ok, external_items} <- list_external_event_items(scope) do
      internal_items =
        entries
        |> Enum.map(fn entry -> List.first(entry.publications) end)
        |> with_author_memberships()

      (internal_items ++ external_items)
      |> Enum.reject(&is_nil(&1.event.starts_at))
      |> Enum.sort_by(&{DateTime.to_unix(&1.event.starts_at, :microsecond), &1.id})
    else
      err ->
        Log.scoped_error(scope, err, "list_aggregate_feed_events failed")
        []
    end
  end

  defp list_external_event_items(scope) do
    with {:ok, spaces} <- Accounts.list_spaces(scope: scope),
         {:ok, participations} <- external_event_participations(scope, spaces) do
      {:ok,
       Enum.map(participations, fn participation ->
         external_event = participation.external_event

         %{
           id: "external:#{external_event.id}",
           source_type: :external,
           event: external_event,
           publication: nil,
           event_url: external_event.event_url,
           external_uid: external_event.external_uid,
           external_recurrence_id: external_event.external_recurrence_id,
           space_slug: nil,
           source_name: nil,
           author: nil,
           calendar_name: external_calendar_name(external_event),
           current_member_participation: participation,
           participations: [participation],
           source_url: nil,
           subscription_id: external_event.subscription_id
         }
       end)}
    end
  end

  defp external_event_participations(scope, spaces) do
    spaces
    |> Enum.reduce_while({:ok, []}, fn space, {:ok, participations} ->
      case Accounts.get_membership(space.id, scope.actor.id) do
        {:ok, nil} ->
          {:cont, {:ok, participations}}

        {:ok, membership} ->
          space_scope = %{scope | tenant: space}

          query =
            EventParticipation
            |> Ash.Query.filter(membership_id == ^membership.id and not is_nil(external_event_id))
            |> Ash.Query.load([:membership, external_event: [:subscription]])

          case Ash.read(query, scope: space_scope) do
            {:ok, space_participations} ->
              {:cont, {:ok, participations ++ space_participations}}

            {:error, error} ->
              {:halt, {:error, error}}
          end

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
  end

  defp external_calendar_name(%{subscription: %Ash.NotLoaded{}} = event), do: event.calendar_name

  defp external_calendar_name(%{subscription: subscription} = event)
       when not is_nil(subscription) do
    ExternalCalendar.display_name(subscription, event.calendar_name)
  end

  defp external_calendar_name(event), do: event.calendar_name

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
