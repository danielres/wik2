defmodule QblogWeb.MeLive do
  use QblogWeb, :live_view
  alias QblogWeb.Components
  alias Qblog.Accounts
  alias Utils.Log

  on_mount {QblogWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    groups = scope |> list_groups()
    socket = socket |> assign(groups: groups)
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} scope={@current_scope}>
      <Layouts.container>
        <div>
          <h1 class="text-2xl font-[100] flex justify-between items-center">
            <span>Your account</span>
            <QblogWeb.Layouts.theme_toggle />
          </h1>
        </div>

        <div class="flex flex-col md:flex-row gap-4 mt-4 [&>div]:flex-1">
          <div class="card bg-base-100 shadow flex-1">
            <div class="card-body">
              <h2 class="text-xl">Your groups</h2>
              <Components.Group.list groups={@groups} />
            </div>
          </div>

          <div class="card bg-base-100 shadow">
            <div class="card-body">
              <h2 class="text-xl">Details</h2>

              <table class="text-left space-y-2">
                <tr>
                  <th>role</th>
                  <td>{@current_user.role}</td>
                </tr>
                <tr>
                  <th>email</th>
                  <td>{@current_user.email}</td>
                </tr>
                <tr>
                  <th>username</th>
                  <td>{@current_user |> to_string()}</td>
                </tr>
              </table>
            </div>
          </div>
        </div>
      </Layouts.container>
    </Layouts.app>
    """
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
