defmodule QblogWeb.GroupLive do
  use QblogWeb, :live_view

  on_mount {QblogWeb.LiveUserAuth, :live_scope_required}

  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    group = socket.assigns.current_scope.tenant
    group = Ash.load!(group, [memberships: [:user]], scope: scope)
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

            <ul class="space-y-0.5">
              <li
                :for={membership <- @group.memberships}
                class={[
                  "flex items-center justify-between gap-1 flex-wrap",
                  "rounded bg-base-200/50 px-3 py-2"
                ]}
              >
                <span>{membership.user |> to_string()}</span>

                <span class={[
                  "flex flex-wrap gap-1",
                  "text-sm opacity-70"
                ]}>
                  <span class={["badge badge-sm px-2 bg-base-300"]}>
                    {membership.type |> Atom.to_string() |> String.capitalize()}
                  </span>

                  <span class={["badge badge-sm px-2 bg-base-300", "whitespace-nowrap"]}>
                    Since {Calendar.strftime(membership.inserted_at, "%Y-%m-%d %H:%M")}
                  </span>
                </span>
              </li>
            </ul>
          </div>
        </div>
      </Layouts.group>
    </Layouts.app>
    """
  end
end
