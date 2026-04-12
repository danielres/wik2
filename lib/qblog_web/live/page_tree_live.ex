defmodule QblogWeb.PageTreeLive do
  use QblogWeb, :live_view
  use QblogWeb.Presence.Handlers

  alias Qblog.Wiki
  alias QblogWeb.PageTreeLive.PageTreeEditor

  on_mount {QblogWeb.LiveUserAuth, :live_scope_required}
  on_mount {QblogWeb.LiveUserAuth, :subscribe_presence}

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    page_tree = scope |> Wiki.load_page_tree()
    {:ok, socket |> assign(page_tree: page_tree)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} scope={@current_scope}>
      <Layouts.group presences={@presences} scope={@current_scope} view="tree">
        <.live_component
          current_scope={@current_scope}
          editable?={true}
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
