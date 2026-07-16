defmodule WikWeb.Auth.SignInLive do
  use WikWeb, :live_view

  @dev_routes? Application.compile_env(:wik, :dev_routes, false)

  alias Wik.DevAuth
  alias WikWeb.Auth.ReturnTo

  @impl true
  def mount(_params, session, socket) do
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
     |> assign(:dev_sign_in_users, dev_sign_in_users)
     |> assign(:return_to, return_to(session))}
  end

  slot :inner_block, required: true

  def blockquote(assigns) do
    ~H"""
    <blockquote class={[
      "my-6",
      "text-balance italic text-center",
      "border-y border-base-content/20 py-6"
    ]}>
      {render_slot(@inner_block)}
    </blockquote>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-svh grid place-items-center p-6 space-y-12" data-testid="sign-in-page">
      <div class="text-base-content/70">
        <.blockquote>
          <p>Your attention is a powerful force.</p>
          <p>It's the source of all you'll ever create in your life.</p>
          <p class="mt-6">
            Your phone, your job, the apps, the news.
          </p>
          <p>All day long, things are competing for it…</p>
          <p class="mt-6">
            How about we try something different?
          </p>
        </.blockquote>
      </div>

      <div class="flex w-full max-w-5xl flex-col items-center gap-12">
        <div class="space-y-2">
          <.telegram_login_button return_to={@return_to} />
          <.google_login_button return_to={@return_to} />
        </div>

        <.dev_sign_in :if={@dev_routes?} {assigns} />
      </div>
    </div>
    """
  end

  attr :return_to, :string, required: true

  def google_login_button(assigns) do
    ~H"""
    <.link
      id="google-sign-in"
      data-testid="google-sign-in"
      href={~p"/auth/google?#{[return_to: @return_to]}"}
      class={[
        "btn btn-primary gap-2",
        "w-52",
        "justify-start",
        "opacity-90 hover:opacity-100 transition overflow-hidden justify-center items-center"
      ]}
    >
      <svg xmlns="http://www.w3.org/2000/svg" width="1em" height="1em" viewBox="0 0 24 24">
        <path d="M0 0h24v24H0z" fill="none" />
        <path
          fill="currentColor"
          d="M3.064 7.51A10 10 0 0 1 12 2c2.695 0 4.959.991 6.69 2.605l-2.867 2.868C14.786 6.482 13.468 5.977 12 5.977c-2.605 0-4.81 1.76-5.595 4.123c-.2.6-.314 1.24-.314 1.9s.114 1.3.314 1.9c.786 2.364 2.99 4.123 5.595 4.123c1.345 0 2.49-.355 3.386-.955a4.6 4.6 0 0 0 1.996-3.018H12v-3.868h9.418c.118.654.182 1.336.182 2.045c0 3.046-1.09 5.61-2.982 7.35C16.964 21.105 14.7 22 12 22A9.996 9.996 0 0 1 2 12c0-1.614.386-3.14 1.064-4.49"
        />
      </svg>

      <span>Sign in with Google</span>
    </.link>
    """
  end

  attr :class, :string, default: nil
  attr :request_access, :string, default: "write"
  attr :return_to, :string, required: true
  attr :size, :string, default: "large", values: ~w(small medium large)

  def telegram_login_button(assigns) do
    assigns = assign(assigns, :bot_username, System.fetch_env!("TELEGRAM_BOT_USERNAME"))

    ~H"""
    <div class={[
      "stacked",
      "opacity-90 hover:opacity-100 transition overflow-hidden justify-center items-center"
    ]}>
      <div class={[
        "btn btn-primary gap-2",
        "justify-start",
        "w-52"
      ]}>
        <svg xmlns="http://www.w3.org/2000/svg" class="size-4" viewBox="0 0 24 24">
          <path d="M0 0h24v24H0z" fill="none" />
          <path
            fill="currentColor"
            d="M2.148 11.81q7.87-3.429 10.497-4.522c4.999-2.079 6.037-2.44 6.714-2.452c.15-.003.482.034.698.21c.182.147.232.347.256.487s.054.459.03.708c-.27 2.847-1.443 9.754-2.04 12.942c-.252 1.348-.748 1.8-1.23 1.845c-1.045.096-1.838-.69-2.85-1.354c-1.585-1.039-2.48-1.686-4.018-2.699c-1.777-1.171-.625-1.815.388-2.867c.265-.275 4.87-4.464 4.96-4.844c.01-.048.021-.225-.084-.318c-.105-.094-.26-.062-.373-.036q-.239.054-7.592 5.018q-1.079.74-1.952.721c-.643-.014-1.88-.363-2.798-.662c-1.128-.367-2.024-.56-1.946-1.183q.061-.486 1.34-.994"
          />
        </svg>
        <span>Sign in with Telegram</span>
      </div>

      <div
        id="telegram-login"
        class={[@class, "opacity-0"]}
        data-bot-username={@bot_username}
        data-request-access={@request_access}
        data-return-to={@return_to}
        data-size={@size}
        phx-hook="TelegramLogin"
        phx-update="ignore"
      />
    </div>
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

  defp return_to(session) do
    session_return_to =
      case session do
        %{"return_to" => return_to} when is_binary(return_to) -> return_to
        %{return_to: return_to} when is_binary(return_to) -> return_to
        _ -> nil
      end

    ReturnTo.validate(session_return_to)
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
