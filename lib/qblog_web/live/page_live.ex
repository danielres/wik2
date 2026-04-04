defmodule QblogWeb.PageLive do
  use QblogWeb, :live_view

  alias Qblog.Wiki
  alias Qblog.Wiki.PageTree.TreeQueries
  alias Qblog.Wiki.PageTree.Node
  alias QblogWeb.Components.Modal
  alias Utils.Log

  on_mount {QblogWeb.LiveUserAuth, :live_scope_required}

  @impl true
  def mount(params, _session, socket) do
    path = Enum.join(params["path"], "/")
    scope = socket.assigns.current_scope
    node = scope |> TreeQueries.load_node_by_path(path)
    page = scope |> Node.Helpers.load_or_create_page(node, load: [:author])

    {:ok,
     socket
     |> assign(form_create_page: nil)
     |> assign(path: path)
     |> assign(node: node, page: page)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} scope={@current_scope}>
      <Layouts.group scope={@current_scope}>
        <.render_content
          form_create_page={@form_create_page}
          node={@node}
          page={@page}
          path={@path}
        />
      </Layouts.group>
    </Layouts.app>
    """
  end

  defp render_content(assigns = %{node: nil, page: nil}) do
    ~H"""
    <.feedback_message>
      <div class="text-lg font-thin">Page not found at this path</div>
      <div class="font-mono">/{@path}</div>
      <:actions>
        <button class="btn btn-primary" phx-click="create_page_start">Create page</button>
      </:actions>
    </.feedback_message>

    <Modal.render
      cancel="create_page_cancel"
      cancel_testid="create-page-cancel"
      open?={@form_create_page != nil}
      testid="create-page-dialog"
    >
      <.form
        :if={@form_create_page != nil}
        for={@form_create_page}
        id="create-page-form"
        phx-submit="create_page_submit"
      >
        <.input field={@form_create_page[:title]} label="Page title" />
        <.button class="btn btn-primary mt-4" type="submit">Create page</.button>
      </.form>
    </Modal.render>
    """
  end

  defp render_content(assigns = %{node: _node, page: nil}) do
    ~H"""
    <h1 class="text-2xl">{@node.title}</h1>

    <.feedback_message>
      <div class="text-lg font-thin">Creating the page for this node...</div>
    </.feedback_message>
    """
  end

  defp render_content(assigns = %{node: _node, page: _page}) do
    ~H"""
    <h1 class="text-2xl">{@node.title}</h1>
    <div>page id: {@page.id}</div>
    <div>page author: {@page.author |> to_string()}</div>
    <div>inserted_at: {@page.inserted_at |> Utils.Time.relative()}</div>
    """
  end

  slot :inner_block, required: true
  slot :actions, required: false

  defp feedback_message(assigns) do
    ~H"""
    <div class="flex flex-col items-center gap-4">
      <div class="alert bg-base-100 flex items-center gap-4 px-8">
        <.icon name="hero-information-circle-solid" class="size-8 opacity-20" />
        <div>
          {render_slot(@inner_block)}
        </div>
      </div>

      <div>
        {render_slot(@actions)}
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("create_page_start", _params, socket) do
    title = socket.assigns.path |> Node.Helpers.path_to_default_title()
    {:noreply, socket |> assign(form_create_page: %{"title" => title} |> to_form())}
  end

  @impl true
  def handle_event("create_page_cancel", _params, socket) do
    {:noreply, socket |> assign(form_create_page: nil)}
  end

  @impl true
  def handle_event("create_page_submit", %{"title" => title}, socket) do
    scope = socket.assigns.current_scope
    path = socket.assigns.path

    case Wiki.create_page_at_path(path, title, scope: scope) do
      {:ok, _page} ->
        node = scope |> TreeQueries.load_node_by_path(path)
        page = scope |> Node.Helpers.load_or_create_page(node, load: [:author])
        {:noreply, socket |> assign(node: node, page: page)}

      {:error, error} ->
        Log.scoped_error(scope, error, "create_page_at_path failed")
        {:noreply, socket |> put_flash(:error, "Could not create page")}
    end
  end
end
