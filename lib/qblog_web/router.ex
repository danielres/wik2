defmodule QblogWeb.Router do
  use QblogWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {QblogWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :group_tenant do
    plug QblogWeb.Plugs.SetTenantFromGroup
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
  end

  if Application.compile_env(:qblog, :dev_routes) do
    import AshAdmin.Router

    scope "/admin" do
      pipe_through :browser
      ash_admin "/"
    end
  end

  scope "/", QblogWeb do
    pipe_through :browser

    auth_routes AuthController, Qblog.Accounts.User, path: "/auth"
    sign_out_route AuthController

    # Remove these if you'd like to use your own authentication views
    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{QblogWeb.LiveUserAuth, :live_no_user}],
                  overrides: [
                    QblogWeb.AuthOverrides,
                    Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                  ]

    # Remove this if you do not want to use the reset password feature
    reset_route auth_routes_prefix: "/auth",
                overrides: [
                  QblogWeb.AuthOverrides,
                  Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                ]

    # Remove this if you do not use the confirmation strategy
    confirm_route Qblog.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [QblogWeb.AuthOverrides, Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI]

    # Remove this if you do not use the magic link strategy.
    magic_sign_in_route(Qblog.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      overrides: [QblogWeb.AuthOverrides, Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI]
    )
  end

  scope "/", QblogWeb do
    ash_authentication_live_session :authenticated_routes do
      pipe_through [:browser]
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
        # on_mount {QblogWeb.LiveUserAuth, :live_scope_required}
        #
        # If an authenticated user must be present:
        # on_mount {QblogWeb.LiveUserAuth, :live_user_required}
        #
        # If an authenticated user must *not* be present:
        # on_mount {QblogWeb.LiveUserAuth, :live_no_user}
      end
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", QblogWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:qblog, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: QblogWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
