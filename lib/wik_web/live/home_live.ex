defmodule WikWeb.HomeLive do
  use WikWeb, :live_view

  require Ash.Query

  alias AshPhoenix.Form
  alias Wik.Accounts
  alias Wik.Accounts.Space
  alias Wik.Activity
  alias Wik.Events
  alias WikWeb.Components
  alias WikWeb.Components.Activity, as: ActivityComponent
  alias WikWeb.Components.UI
  alias WikWeb.EventsLive.TimelinePresenter
  alias Utils.Log

  on_mount {WikWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:activity_query, Activity.aggregate_entries_query())
      |> assign(:create_space_modal_open?, false)
      |> assign(:subscribed_activity_space_ids, MapSet.new())
      |> assign_spaces_and_form()
      |> subscribe_to_activity()

    {:ok, socket}
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

  attr :spaces, :list, required: true
  attr :user_tz, :string, required: true

  defp spaces_grid(assigns) do
    ~H"""
    <div class={[
      "autogrid",
      "gap-2",
      "auto-rows-[minmax(0,1fr)]",
      "[--autogrid-min:9rem]"
    ]}>
      <.link
        :for={space <- @spaces}
        data-testid={"home-space-link-#{space.id}"}
        class={[
          "bg-base-content/5",
          "hover:bg-base-content/10",
          "opacity-80",
          "hover:opacity-100",
          "transition",
          "text-xs font-bold",
          "leading-tight",
          "cursor-pointer",
          "p-4 pb-2",
          "grid grid-rows-[1fr_auto]",
          "space-y-4"
        ]}
        navigate={~p"/#{space.slug}"}
      >
        <h3>{space.name}</h3>

        <div
          data-testid={"home-space-last-update-#{space.id}"}
          class="flex gap-1 justify-end items-center"
        >
          <%= if space.last_activity_at do %>
            <.icon name="hero-arrow-path-micro" class="size-3 opacity-60" />

            <Components.Time.relative_and_precise
              :if={space.last_activity_at}
              datetime={space.last_activity_at}
              user_tz={@user_tz}
              ago?
            />
          <% else %>
            <span class="sr-only">No updates yet</span>
          <% end %>
        </div>
      </.link>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app context={@context} flash={@flash} scope={@current_scope} home?={true}>
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

            <.spaces_grid spaces={@spaces} user_tz={@active_tz} />

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
              <span>Participation </span>
              <Components.CalendarFeed.aggregate_subscribe_button scope={@current_scope} />
            </UI.panel_title>
            <div
              :if={@grouped_event_items == []}
              class={[
                "text-sm opacity-50",
                "flex justify-between items-center",
                "bg bg-base-200 p-4 rounded"
              ]}
            >
              <div>No upcoming events</div>
              <.icon name="hero-information-circle" />
            </div>

            <div style="--top: 0rem">
              <Components.Event.grouped_timeline
                current_scope={@current_scope}
                grouped_items={@grouped_event_items}
                source_label_mode={:aggregate}
                user_tz={@active_tz}
              />
            </div>
          </section>

          <sections>
            <ActivityComponent.preview
              id="home-activity"
              query={@activity_query}
              scope={@current_scope}
              show_space?
              user_tz={@active_tz}
            />
          </sections>
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
          |> subscribe_to_activity()
          |> assign(:create_space_modal_open?, false)

        {:noreply, socket}

      {:error, form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Something went wrong")
         |> assign(form: form)}
    end
  end

  @impl true
  def handle_info(%{topic: "activity_entry:space:" <> space_id}, socket) do
    if MapSet.member?(socket.assigns.subscribed_activity_space_ids, space_id) do
      socket =
        socket
        |> assign_spaces()
        |> Cinder.Refresh.refresh_table("home-activity-preview-collection")

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp assign_spaces_and_form(socket) do
    scope = socket.assigns.current_scope
    event_items = list_aggregate_event_items(scope)

    socket
    |> assign(event_items: event_items)
    |> assign(grouped_event_items: TimelinePresenter.grouped_timeline_items(event_items))
    |> assign(form: scope |> init_form())
    |> assign_spaces()
  end

  defp assign_spaces(socket) do
    assign(socket, :spaces, list_spaces(socket.assigns.current_scope))
  end

  defp subscribe_to_activity(socket) do
    if connected?(socket) do
      subscribed_space_ids = socket.assigns.subscribed_activity_space_ids
      space_ids = MapSet.new(socket.assigns.spaces, & &1.id)

      space_ids
      |> MapSet.difference(subscribed_space_ids)
      |> Enum.each(&Activity.subscribe/1)

      assign(
        socket,
        :subscribed_activity_space_ids,
        MapSet.union(subscribed_space_ids, space_ids)
      )
    else
      socket
    end
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
    with {:ok, spaces} <-
           Accounts.list_spaces(
             scope: scope,
             load: [:last_activity_at]
           ) do
      Enum.sort_by(spaces, &space_activity_sort_key/1)
    else
      err ->
        Log.scoped_error(scope, err, "list_spaces failed")
        []
    end
  end

  defp space_activity_sort_key(space) do
    {
      is_nil(space.last_activity_at),
      -datetime_sort_value(space.last_activity_at),
      space_name_sort_key(space.name),
      space.name
    }
  end

  defp space_name_sort_key(name) do
    name
    |> String.graphemes()
    |> Enum.drop_while(&(not String.match?(&1, ~r/[\p{L}\p{N}]/u)))
    |> Enum.join()
    |> String.downcase()
  end

  defp datetime_sort_value(nil), do: -1
  defp datetime_sort_value(datetime), do: DateTime.to_unix(datetime, :microsecond)

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
