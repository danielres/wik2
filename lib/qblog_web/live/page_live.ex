defmodule QblogWeb.PageLive do
  use QblogWeb, :live_view

  # alias Qblog.Blog
  # alias Qblog.Blog.Post
  # alias AshPhoenix.Form
  # alias Utils.Time
  # alias Utils.Log

  on_mount {QblogWeb.LiveUserAuth, :live_scope_required}

  def mount(params, _session, socket) do
    # scope = socket.assigns.current_scope
    path_segments = params["path"]
    path = path_segments |> Enum.join("/")
    socket = socket |> assign(path: path)
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} scope={@current_scope}>
      <Layouts.group scope={@current_scope}>
        Wiki page
        <div>
          path: {@path}
        </div>
      </Layouts.group>
    </Layouts.app>
    """
  end
end
