defmodule WikWeb.SpaceUpdatesLive do
  use WikWeb, :live_view
  use Cinder.UrlSync

  alias Wik.Activity
  alias WikWeb.Components.Activity, as: ActivityComponent
  alias WikWeb.Components.UI

  on_mount {WikWeb.LiveUserAuth, :live_scope_required}

  @impl true
  def mount(_params, _session, socket) do
    space = socket.assigns.current_scope.tenant

    if connected?(socket), do: Activity.subscribe(space.id)

    {:ok,
     socket
     |> assign(:activity_category, :all)
     |> assign(:activity_query, Activity.entries_query())
     |> assign(:params, %{})
     |> assign(:space, space)}
  end

  @impl true
  def handle_params(params, uri, socket) do
    category = ActivityComponent.param_to_category(params["category"])

    socket =
      params
      |> Cinder.UrlSync.handle_params(uri, socket)
      |> assign(:activity_category, category)
      |> assign(:activity_query, Activity.entries_query(category))
      |> assign(:params, params)

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %{topic: "activity_entry:space:" <> space_id},
        %{assigns: %{space: %{id: space_id}}} = socket
      ) do
    {:noreply, Cinder.Refresh.refresh_table(socket, "space-activity-table-collection")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      context={@context}
      flash={@flash}
      scope={@current_scope}
      tenant_context={@tenant_context}
    >
      <Layouts.space scope={@current_scope} view="updates">
        <div class="max-w-[80ch]">
          <UI.page_head>
            <UI.page_title>
              <.icon name="hero-arrow-path-micro" class="opacity-50" /> Updates
            </UI.page_title>
          </UI.page_head>

          <section>
            <ActivityComponent.category_nav
              active_category={@activity_category}
              category_paths={category_paths(@space, @params)}
            />

            <ActivityComponent.collection
              id="space-activity-table-collection"
              page_size={[default: 10, options: [10, 25, 50, 100]]}
              query={@activity_query}
              scope={@current_scope}
              search={[placeholder: "Search updates"]}
              url_state={@url_state}
              user_tz={@active_tz}
              wrapper_id="space-activity-table"
            />
          </section>
        </div>
      </Layouts.space>
    </Layouts.app>
    """
  end

  defp category_paths(space, params) do
    Map.new([:all | Activity.categories()], &{&1, category_path(space, params, &1)})
  end

  defp category_path(space, params, category) do
    params = Map.drop(params, ["after", "before", "page", "space_slug"])

    params =
      if category == :all do
        Map.delete(params, "category")
      else
        Map.put(params, "category", Atom.to_string(category))
      end

    path = ~p"/#{space.slug}/updates"

    if params == %{}, do: path, else: path <> "?" <> URI.encode_query(params)
  end
end
