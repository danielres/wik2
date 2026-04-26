defmodule QblogWeb.PageTreeLive do
  use QblogWeb, :live_view
  use QblogWeb.Presence.Handlers

  alias QblogWeb.PageTreeLive.PageTreeEditor

  on_mount {QblogWeb.LiveUserAuth, :live_scope_required}
  on_mount {QblogWeb.LiveUserAuth, :subscribe_presence}

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    page_tree = Qblog.Wiki.load_page_tree(scope)
    editable? = page_tree.id != nil and Ash.can?({page_tree, :manage_tree}, scope)

    {:ok, socket |> assign(page_tree: page_tree, editable?: editable?)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app context={@context} flash={@flash} scope={@current_scope}>
      <Layouts.group presences={@presences} scope={@current_scope} view="tree">
        <div class="flex items-center gap-4 mb-4">
          <h1 class="text-xl font-[100] flex items-center justify-between gap-4 mb-0">
            <div>
              <span class="font-[400] opacity-70 flex items-center flex-wrap gap-2">
                <.link
                  navigate={~p"/#{@current_scope.tenant.name}"}
                  class={[
                    "opacity-50 hover:opacity-100 transition-opacity",
                    "leading-none"
                  ]}
                >
                  {@current_scope.tenant.name |> String.capitalize()}
                </.link>
                <.icon name="hero-chevron-right-mini" class="opacity-50" />
                <span class="text-base">Page tree</span>
              </span>
            </div>
          </h1>
        </div>
        <.live_component
          current_scope={@current_scope}
          editable?={@editable?}
          id="page_tree_editor"
          module={PageTreeEditor}
          page_tree={@page_tree}
        />
      </Layouts.group>
    </Layouts.app>
    """
  end

  @impl true
  def handle_params(_params, url, socket) do
    {:noreply, QblogWeb.Presence.track_in_liveview(socket, url)}
  end

  @impl true
  def handle_info({:page_tree_updated, page_tree}, socket) do
    {:noreply, socket |> assign(page_tree: page_tree)}
  end
end
