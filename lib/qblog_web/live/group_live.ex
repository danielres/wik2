defmodule QblogWeb.GroupLive do
  use QblogWeb, :live_view

  on_mount {QblogWeb.LiveUserAuth, :live_scope_required}

  def mount(_params, _session, socket) do
    # scope = socket.assigns.current_scope

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} scope={@current_scope}>
      <Layouts.group scope={@current_scope}>
        <h1 class="text-2xl font-[100]">
          <span>{@current_scope.tenant.name |> String.capitalize()}</span>
          <span class="opacity-50">
            <span>|</span>
            <span>group details</span>
          </span>
        </h1>
      </Layouts.group>
    </Layouts.app>
    """
  end
end
