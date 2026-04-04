defmodule QblogWeb.PageTreeLive do
  use QblogWeb, :live_view

  alias Qblog.Wiki
  alias QblogWeb.PageTreeLive.PageTreeEditor

  on_mount {QblogWeb.LiveUserAuth, :live_scope_required}

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
      <Layouts.group scope={@current_scope}>
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
  def handle_info({:page_tree_updated, page_tree}, socket) do
    {:noreply, socket |> assign(page_tree: page_tree)}
  end
end
