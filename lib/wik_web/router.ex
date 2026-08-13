defmodule WikWeb.Router do
  use WikWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers
  import WikWeb.ErrorTrackerRouter

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WikWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
    plug WikWeb.Plugs.SetErrorTrackerContext
  end

  pipeline :space_tenant do
    plug WikWeb.Plugs.SetTenantFromSpace
    plug WikWeb.Plugs.SetErrorTrackerContext
  end

  pipeline :store_return_to do
    plug WikWeb.Plugs.StoreReturnTo
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
  end

  pipeline :webhook do
    plug :accepts, ["json"]
  end

  if Application.compile_env(:wik, :editor_test_routes, false) do
    scope "/__test__", WikWeb do
      pipe_through :browser

      live "/lexical-editor", LexicalEditorTestLive
    end
  end

  if Application.compile_env(:wik, :dev_routes) do
    import AshAdmin.Router

    scope "/admin" do
      pipe_through :browser
      ash_admin "/"
    end

    scope "/" do
      pipe_through :browser
    end
  end

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

  scope "/", WikWeb do
    pipe_through :browser

    live "/docs/*path", DocsLive
    get "/privacy", PageController, :privacy
    get "/terms", PageController, :terms
    get "/auth/google", AuthController.Google, :request
    get "/auth/google/callback", AuthController.Google, :callback
    get "/auth/telegram/callback", AuthController.Telegram, :callback
    get "/avatars/google/:token", GoogleAvatarController, :show

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
    get "/calendar/:token", CalendarFeedController, :show
  end

  scope "/", WikWeb do
    pipe_through [:browser, :store_return_to]

    superadmin_error_tracker_dashboard("/errors")

    ash_authentication_live_session :superadmin_routes,
      on_mount: [{WikWeb.LiveUserAuth, :live_superadmin_required}] do
      scope "/_", Superadmin do
        live "/", TelegramBotUpdatesLive
        live "/inbox", InboxLive
      end
    end

    ash_authentication_live_session :authenticated_routes do
      live "/", HomeLive, :index
      live "/me", Me.SettingsLive, :index
      live "/me/access", Me.AccessLive, :index
      live "/me/tickets", Me.TicketsLive, :index
      live "/me/tickets/new", Me.NewTicketLive, :new

      scope "/:space_slug" do
        pipe_through [:space_tenant]
        live "/", SpaceLive
        live "/activity", SpaceUpdatesLive
        live "/members", MembersLive
        live "/admin", SpaceAdminLive
        live "/topics", TagGraphLive, :index
        live "/topics/:tag_slug", TagLive, :tag
        live "/events", EventsLive, :index
        live "/tree", PageTreeLive, :index
        live "/blog", BlogLive, :index

        scope "/wiki" do
          get "/", WikiRedirectController, :home
          live "/members/:username", MemberProfileLive, :show
          live "/members/:username/tag/:tag_slug", MemberProfileLive, :tag
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
end
