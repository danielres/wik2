defmodule WikWeb.Router do
  use WikWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WikWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :group_tenant do
    plug WikWeb.Plugs.SetTenantFromGroup
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
  end

  pipeline :webhook do
    plug :accepts, ["json"]
  end

  if Application.compile_env(:wik, :dev_routes) do
    import AshAdmin.Router

    scope "/admin" do
      pipe_through :browser
      ash_admin "/"
    end
  end

  scope "/", WikWeb do
    pipe_through :browser

    get "/auth/telegram/callback", AuthController.Telegram, :callback

    if Application.compile_env(:wik, :dev_routes) do
      post "/auth/dev/sign-in", AuthController.Dev, :create
    end

    ash_authentication_live_session :signed_out_routes,
      on_mount: [{WikWeb.LiveUserAuth, :live_no_user}] do
      live "/sign-in", Auth.SignInLive, :index
    end

    ash_authentication_live_session :telegram_source_routes,
      on_mount: [{WikWeb.LiveUserAuth, :live_user_required}] do
      live "/auth/telegram", Auth.TelegramSourcesLive, :index
    end

    auth_routes AuthController, Wik.Accounts.User, path: "/auth"
    sign_out_route AuthController

    # Remove this if you do not want to use the reset password feature
    reset_route auth_routes_prefix: "/auth",
                overrides: [
                  WikWeb.AuthOverrides,
                  Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                ]

    # Remove this if you do not use the confirmation strategy
    confirm_route Wik.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [WikWeb.AuthOverrides, Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI]

    # Remove this if you do not use the magic link strategy.
    magic_sign_in_route(Wik.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      overrides: [WikWeb.AuthOverrides, Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI]
    )
  end

  scope "/webhooks", WikWeb.Webhooks do
    pipe_through :webhook

    post "/telegram", TelegramController, :create
  end

  scope "/", WikWeb do
    pipe_through [:browser]

    ash_authentication_live_session :superadmin_routes,
      on_mount: [{WikWeb.LiveUserAuth, :live_superadmin_required}] do
      scope "/_", Superadmin do
        live "/", TelegramBotUpdatesLive
      end
    end

    ash_authentication_live_session :authenticated_routes do
      live "/", HomeLive, :index
      live "/me", MeLive, :index

      scope "/:group_name" do
        pipe_through [:group_tenant]
        live "/", GroupLive, :members
        live "/members", GroupLive, :members
        live "/orphans", GroupLive, :orphans
        live "/tree", PageTreeLive, :index
        live "/blog", BlogLive, :index

        scope "/wiki" do
          get "/", WikiRedirectController, :home
          live "/*path", PageLive, :index
        end

        # in each liveview, add one of the following at the top of the module:
        #
        # If an authenticated user & tenant must be present:
        # on_mount {WikWeb.LiveUserAuth, :live_scope_required}
        #
        # If an authenticated user must be present:
        # on_mount {WikWeb.LiveUserAuth, :live_user_required}
        #
        # If an authenticated user must *not* be present:
        # on_mount {WikWeb.LiveUserAuth, :live_no_user}
      end
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", WikWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:wik, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: WikWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
