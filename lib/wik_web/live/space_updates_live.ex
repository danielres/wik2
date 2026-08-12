defmodule WikWeb.SpaceUpdatesLive do
  use WikWeb, :live_view
  use Cinder.UrlSync

  alias Wik.Activity
  alias Wik.Activity.Entry
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
    category = param_to_category(params["category"])

    socket =
      params
      |> Cinder.UrlSync.handle_params(uri, socket)
      |> assign(:activity_category, category)
      |> assign(:activity_query, Activity.entries_query(category))
      |> assign(:params, params)

    {:noreply, socket}
  end

  @impl true
  def handle_info(%{topic: topic}, socket) do
    if topic == Entry.space_pub_sub_topic(socket.assigns.space.id) do
      {:noreply, Cinder.Refresh.refresh_table(socket, "space-activity-table-collection")}
    else
      {:noreply, socket}
    end
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
            <nav
              aria-label="Filter updates by category"
              class="flex flex-wrap gap-1 ml-3"
              id="activity-category-filter"
            >
              <.link
                :for={category <- [:all | Activity.categories()]}
                patch={category_path(@space, @params, category)}
                class={[
                  "flex items-center gap-1",
                  "relative top-1",
                  "bg-base-200",
                  "px-4 py-2",
                  "font-bold text-sm",
                  "transition",
                  "rounded-t-box rounded-b-none ",
                  @activity_category != category && "opacity-30 hover:opacity-70 btn-ghost"
                ]}
                id={"activity-category-#{category}"}
              >
                <div class="opacity-60 inline-flex">
                  <.icon :if={category == :all} name="hero-eye-micro" />
                  <.icon :if={category == :wiki} name="hero-book-open-micro" />
                  <.icon :if={category == :topics} name="hero-tag-micro" />
                  <.icon :if={category == :events} name="hero-calendar-micro" />
                  <.icon :if={category == :members} name="hero-user-micro" />
                  <.icon :if={category == :other} name="hero-ellipsis-horizontal-micro" />
                </div>
                <span class={@activity_category != category && "max-sm:sr-only"}>
                  {category_label(category)}
                </span>
              </.link>
            </nav>

            <div id="space-activity-table">
              <Cinder.collection
                empty_message="No updates in this category yet."
                id="space-activity-table-collection"
                page_size={[default: 10, options: [10, 25, 50, 100]]}
                query={@activity_query}
                query_opts={[
                  load: [
                    :event_starts_at,
                    actor_membership: [:avatar_url, :space, user: [:external_identities]]
                  ]
                ]}
                scope={@current_scope}
                search={[placeholder: "Search updates"]}
                show_filters={false}
                sort_mode="exclusive"
                theme={WikWeb.Cinder.Themes.Dense}
                url_state={@url_state}
                class={[
                  "[&_thead]:hidden",
                  "[&>*>*]:pt-2",
                  "[&>*>*]:pb-4"
                ]}
              >
                <:col :let={entry} field="actor_label" label="">
                  <ActivityComponent.actor entry={entry} />
                </:col>

                <:col :let={entry} field="subject_label" label="">
                  <div data-testid={"activity-entry-#{entry.id}"}>
                    <ActivityComponent.summary entry={entry} />
                    <ActivityComponent.note entry={entry} />
                  </div>
                </:col>

                <:col :let={entry} field="occurred_at" label="" class="w-0">
                  <WikWeb.Components.Time.relative_and_precise
                    ago?
                    datetime={entry.occurred_at}
                    user_tz={@active_tz}
                    class="text-xs"
                  />
                </:col>
              </Cinder.collection>
            </div>
          </section>
        </div>
      </Layouts.space>
    </Layouts.app>
    """
  end

  defp param_to_category(nil), do: :all

  defp param_to_category(category) do
    Enum.find(Activity.categories(), :all, &(Atom.to_string(&1) == category))
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

  defp category_label(:all), do: "All"
  defp category_label(:events), do: "Events"
  defp category_label(:members), do: "Members"
  defp category_label(:other), do: "Other"
  defp category_label(:topics), do: "Topics"
  defp category_label(:wiki), do: "Wiki"
end
