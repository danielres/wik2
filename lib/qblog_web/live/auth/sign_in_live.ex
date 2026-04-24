defmodule QblogWeb.Auth.SignInLive do
  use QblogWeb, :live_view

  @dev_routes? Application.compile_env(:qblog, :dev_routes, false)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:dev_routes?, @dev_routes?)
     |> assign(:dev_sign_in_form, to_form(%{}, as: :dev_sign_in))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-svh grid place-items-center p-6" data-testid="sign-in-page">
      <div class="flex flex-col gap-12 items-center">
        <QblogWeb.Components.Telegram.Widgets.login />

        <div
          :if={@dev_routes?}
          class="card bg-base-300 border border-accent"
          data-testid="dev-sign-in"
        >
          <div class="card-body small-caps">
            <div class="text-center opacity-50">
              Local dev
            </div>

            <.form for={@dev_sign_in_form} action="/auth/dev/sign-in" method="post">
              <button
                type="submit"
                class="btn btn-soft btn-accent"
                data-testid="dev-sign-in-superadmin"
              >
                Sign in as superadmin
              </button>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
