defmodule QblogWeb.GroupLive do
  use QblogWeb, :live_view

  on_mount {QblogWeb.LiveUserAuth, :live_scope_required}

  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    group = socket.assigns.current_scope.tenant
    group = Ash.load!(group, [:users], scope: scope)
    {:ok, socket |> assign(group: group)}
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

        <div class="card card-sm bg-base-100">
          <div class="card-body">
            <h2 class="text-xl">Members</h2>

            <ul class="space-y-1 flex gap-1 flex-wrap">
              <li :for={member <- @group.users} class="badge bg-base-200 px-3 rounded">
                {member |> to_string()}
              </li>
            </ul>
          </div>
        </div>
      </Layouts.group>
    </Layouts.app>
    """
  end
end
