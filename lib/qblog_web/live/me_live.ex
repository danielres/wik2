defmodule QblogWeb.MeLive do
  use QblogWeb, :live_view

  on_mount {QblogWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} scope={@current_scope}>
      <div>
        <h1 class="text-2xl font-[100] flex justify-between items-center">
          <span>Your profile</span>
          <QblogWeb.Layouts.theme_toggle />
        </h1>
      </div>

      <div class="card bg-base-100 shadow">
        <div class="card-body">
          <table class="table">
            <tr>
              <td class="font-bold">role</td>
              <td>{@current_user.role}</td>
            </tr>
            <tr>
              <td class="font-bold">email</td>
              <td>{@current_user.email}</td>
            </tr>
            <tr>
              <td class="font-bold">username</td>
              <td>{@current_user |> to_string()}</td>
            </tr>
          </table>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
