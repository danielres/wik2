defmodule WikWeb.PageTreeLive do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers

  alias WikWeb.PageTreeLive.PageTreeEditor
  alias WikWeb.Components.UI

  on_mount {WikWeb.LiveUserAuth, :live_scope_required}
  on_mount {WikWeb.LiveUserAuth, :subscribe_presence}

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    page_tree = Wik.Wiki.load_page_tree(scope)
    editable? = page_tree.id != nil and Ash.can?({page_tree, :manage_tree}, scope)

    {:ok, socket |> assign(page_tree: page_tree, editable?: editable?, editing?: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      context={@context}
      flash={@flash}
      tenant_context={@tenant_context}
      scope={@current_scope}
    >
      <Layouts.space editing?={@editing?} presences={@presences} scope={@current_scope} view="tree">
        <:actions :if={@editable?}>
          <%= if @editing? do %>
            <UI.button_ok phx-click="toggle_edit_mode" data-testid="tag-edit-mode-ok" />
          <% else %>
            <UI.button_edit
              phx-click="toggle_edit_mode"
              data-testid="tag-edit-mode-toggle"
            />
          <% end %>
        </:actions>

        <.live_component
          current_scope={@current_scope}
          editable?={@editable? and @editing?}
          id="page_tree_editor"
          module={PageTreeEditor}
          page_tree={@page_tree}
        />
      </Layouts.space>
    </Layouts.app>
    """
  end

  @impl true
  def handle_params(_params, url, socket) do
    {:noreply, WikWeb.Presence.track_in_liveview(socket, url)}
  end

  @impl true
  def handle_info({:page_tree_updated, page_tree}, socket) do
    {:noreply, socket |> assign(page_tree: page_tree)}
  end

  @impl true
  def handle_event("toggle_edit_mode", _params, socket) do
    socket = assign(socket, editing?: !socket.assigns.editing?)

    {:noreply, socket}
  end
end
