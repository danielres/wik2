defmodule QblogWeb.HomeLive do
  use QblogWeb, :live_view

  alias Qblog.Accounts
  alias Qblog.Accounts.Group
  alias AshPhoenix.Form
  alias Utils.Log

  on_mount {QblogWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_groups_and_form()
     |> assign(fields: Ash.Resource.Info.action(Group, :create).accept)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} scope={@current_scope}>
      <Layouts.container>
        <h1 class="text-2xl font-[100]">Your groups</h1>
        <div class="flex gap-4">
          <ul class="space-y-2 flex-1">
            <li class="card bg-base-100 shadow">
              <div class="card-body">
                <.link
                  :for={group <- @groups}
                  class="btn btn-soft justify-between"
                  navigate={~p"/#{group.name}"}
                >
                  {group.name}
                  <span class="font-thin">{group.owner |> to_string}</span>
                </.link>

                <span :if={@groups == []} class="opacity-70">
                  You are not a member of any groups yet.
                </span>
              </div>
            </li>
          </ul>

          <.form
            :if={Ash.can?({Group, :create}, @current_scope)}
            class="flex-1"
            for={@form}
            phx-change="validate"
            phx-submit="submit"
          >
            <div class="card bg-base-300">
              <div class="card-body">
                <.input
                  :for={field <- @fields}
                  type={Group.field_type_for(field)}
                  field={@form[field]}
                  label={field |> Phoenix.Naming.humanize()}
                />
                <.button type="submit" class="btn btn-primary mt-3">Create group</.button>
              </div>
            </div>
          </.form>
        </div>
      </Layouts.container>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, socket |> assign(form: socket.assigns.form |> Form.validate(params))}
  end

  def handle_event("submit", %{"form" => params}, socket) do
    case socket.assigns.form |> Form.submit(params: params) do
      {:ok, _group} ->
        {:noreply, socket |> assign_groups_and_form()}

      {:error, form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Something went wrong")
         |> assign(form: form)}
    end
  end

  defp assign_groups_and_form(socket) do
    scope = socket.assigns.current_scope

    socket
    |> assign(groups: scope |> list_groups())
    |> assign(form: scope |> init_form())
  end

  defp init_form(scope) do
    Group |> Form.for_create(:create, scope: scope) |> to_form()
  end

  defp list_groups(nil), do: []

  defp list_groups(scope) do
    with {:ok, groups} <- Accounts.list_groups(scope: scope) do
      groups
    else
      err ->
        Log.scoped_error(scope, err, "list_groups failed")
        []
    end
  end
end
