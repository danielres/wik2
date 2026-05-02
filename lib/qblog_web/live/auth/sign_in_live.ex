defmodule QblogWeb.Auth.SignInLive do
  use QblogWeb, :live_view

  @dev_routes? Application.compile_env(:qblog, :dev_routes, false)

  alias Qblog.DevAuth

  @impl true
  def mount(_params, _session, socket) do
    dev_sign_in_users =
      if @dev_routes? do
        case DevAuth.list_sign_in_users() do
          {:ok, users} -> Enum.map(users, &dev_sign_in_user_assigns/1)
          {:error, _error} -> []
        end
      else
        []
      end

    {:ok,
     socket
     |> assign(:dev_routes?, @dev_routes?)
     |> assign(:dev_sign_in_form, to_form(%{}, as: :dev_sign_in))
     |> assign(:dev_sign_in_users, dev_sign_in_users)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} context={@context}>
      <div class="min-h-svh grid place-items-center p-6" data-testid="sign-in-page">
        <div class="flex w-full max-w-5xl flex-col items-center gap-12">
          <QblogWeb.Components.Telegram.Widgets.login />

          <.dev_sign_in :if={@dev_routes?} {assigns} />
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp dev_sign_in_user_assigns(user) do
    %{
      form: to_form(%{"user_id" => user.id}, as: :dev_sign_in),
      label: user |> to_string(),
      secondary_label: "id #{short_user_id(user.id)}",
      user: user
    }
  end

  defp short_user_id(id) do
    id
    |> to_string()
    |> String.split("-")
    |> List.first()
  end

  def dev_sign_in(assigns) do
    ~H"""
    <div
      data-testid="dev-sign-in"
      class="rounded-box bg-accent/10 p-6 border border-accent/40"
    >
      <div class="flex flex-col gap-2 text-center">
        <p class="small-caps tracking-wide text-accent">
          Local dev
        </p>
        <h2 class="text-1xl font-semibold text-accent-content">
          Sign in as any existing user
        </h2>
      </div>

      <div class="mt-6 flex flex-col gap-6">
        <.form
          for={@dev_sign_in_form}
          action="/auth/dev/sign-in"
          method="post"
          class="flex flex-col items-center"
        >
          <button
            id="dev-sign-in-superadmin"
            type="submit"
            class={["btn btn-sm btn-accent rounded"]}
            data-testid="dev-sign-in-superadmin"
          >
            Sign in as superadmin
          </button>
        </.form>

        <div class="space-y-3" data-testid="dev-sign-in-users">
          <div class="flex items-center justify-between gap-3">
            <p class="small-caps tracking-wide text-accent">
              Existing users
            </p>
          </div>

          <div
            :if={@dev_sign_in_users == []}
            class="rounded-2xl border border-dashed border-base-content/15 bg-base-200/70 px-4 py-6 text-center text-sm text-base-content/55"
          >
            No users yet. Use the superadmin shortcut to create the first account.
          </div>

          <div :if={@dev_sign_in_users != []} class="grid gap-3 md:grid-cols-2">
            <.form
              :for={user <- @dev_sign_in_users}
              for={user.form}
              action="/auth/dev/sign-in"
              method="post"
            >
              <.input field={user.form[:user_id]} type="hidden" />
              <button
                id={"dev-sign-in-user-#{user.user.id}"}
                type="submit"
                class={[
                  "btn btn-accent px-4 py-2 h-auto",
                  "flex w-full justify-between gap-4 rounded-box items-baseline",
                  "bg-accent/10 text-left"
                ]}
                data-testid={"dev-sign-in-user-#{user.user.id}"}
              >
                <span class="min-w-0">
                  <span class="block truncate text-sm font-semibold text-accent-content">
                    {user.label}
                  </span>
                  <span class="block text-xs text-accent-content/50">
                    {user.secondary_label}
                  </span>
                </span>

                <span class="badge badge-xs badge-accent bg-accent/60 uppercase ">
                  {user.user.role}
                </span>
              </button>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
