defmodule QblogWeb.PageLive do
  use QblogWeb, :live_view

  alias Qblog.Wiki

  on_mount {QblogWeb.LiveUserAuth, :live_scope_required}

  @impl true
  def mount(params, _session, socket) do
    scope = socket.assigns.current_scope
    path = Enum.join(params["path"], "/")

    {node, page} =
      path |> Wiki.ensure_node_and_page_at_path(scope: scope, load: [:author])

    {:ok,
     socket
     |> assign(form_create_page: nil)
     |> assign(node: node, page: page)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} scope={@current_scope}>
      <Layouts.group scope={@current_scope}>
        <h1 class="text-2xl">{@node.title}</h1>
        <div>page id: {@page.id}</div>
        <div>page author: {@page.author |> to_string()}</div>
        <div>inserted_at: {@page.inserted_at |> Utils.Time.relative()}</div>
      </Layouts.group>
    </Layouts.app>
    """
  end
end
