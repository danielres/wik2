defmodule QblogWeb.GroupLive do
  use QblogWeb, :live_view

  alias AshPhoenix.Form
  alias QblogWeb.Components.Modal
  alias QblogWeb.Components

  on_mount {QblogWeb.LiveUserAuth, :live_scope_required}

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    group = socket.assigns.current_scope.tenant
    group = Ash.load!(group, [memberships: [:user]], scope: scope)

    socket =
      socket
      |> assign(form: nil)
      |> assign(group: group)

    {:ok, socket}
  end

  defp init_form(group, scope) do
    group |> Form.for_update(:update, scope: scope) |> to_form()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} scope={@current_scope}>
      <Layouts.group scope={@current_scope}>
        <h1 class="text-2xl font-[100] flex items-center justify-between gap-4">
          <div>
            <span>{@current_scope.tenant.name |> String.capitalize()}</span>
            <span class="opacity-50">
              <span>|</span>
              <span>group details</span>
            </span>
          </div>

          <button
            :if={Ash.can?({@group, :update}, @current_scope)}
            class="opacity-70 hover:opacity-100 transition-opacity cursor-pointer"
            phx-click="update_group_start"
          >
            <.icon name="hero-pencil-mini" />
          </button>
        </h1>

        <Modal.render
          cancel="update_group_cancel"
          cancel_testid="update-group-cancel"
          open?={@form != nil}
          testid="update-group-dialog"
        >
          <Components.Group.Form.render
            :if={Ash.can?({@group, :update}, @current_scope)}
            action_type="update"
            form={@form}
          />
        </Modal.render>

        <div class="opacity-80">
          {@group.description}
        </div>

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

  @impl true
  def handle_event("update_group_start", _params, socket) do
    group = socket.assigns.group
    scope = socket.assigns.current_scope
    socket = socket |> assign(form: init_form(group, scope))
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_group_cancel", _params, socket) do
    socket = socket |> assign(form: nil)
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, socket |> assign(form: socket.assigns.form |> Form.validate(params))}
  end

  @impl true
  def handle_event("submit", %{"form" => params}, socket) do
    prev_group = socket.assigns.group

    case socket.assigns.form |> Form.submit(params: params) do
      {:ok, group} ->
        if prev_group.name != group.name do
          {:noreply, socket |> Phoenix.LiveView.redirect(to: ~p"/#{group.name}")}
        else
          {:noreply, socket |> assign(group: group, form: nil)}
        end

      {:error, form} ->
        {:noreply,
         socket
         |> assign(form: form)}
    end
  end
end
