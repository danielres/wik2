defmodule WikWeb.ErrorTrackerRouter do
  @moduledoc false

  alias AshAuthentication.Phoenix.LiveSession
  alias ErrorTracker.Web.Hooks.SetAssigns

  def live_session_opts(dashboard_path) do
    LiveSession.opts(
      otp_app: :wik,
      root_layout: {ErrorTracker.Web.Layouts, :root},
      session: [{ErrorTracker.Web.Router, :__session__, [nil]}],
      on_mount: [
        {SetAssigns, {:set_dashboard_path, dashboard_path}},
        {WikWeb.LiveUserAuth, :live_superadmin_required}
      ]
    )
  end

  defmacro superadmin_error_tracker_dashboard(path) do
    dashboard_path = "/_" <> path

    quote bind_quoted: [path: path, dashboard_path: dashboard_path] do
      scope "/_", alias: false, as: false do
        live_session :error_tracker_dashboard,
                     WikWeb.ErrorTrackerRouter.live_session_opts(dashboard_path) do
          scope path, alias: false, as: false do
            live "/", ErrorTracker.Web.Live.Dashboard, :index, as: :error_tracker_dashboard
            live "/:id", ErrorTracker.Web.Live.Show, :show, as: :error_tracker_dashboard

            live "/:id/:occurrence_id", ErrorTracker.Web.Live.Show, :show,
              as: :error_tracker_dashboard
          end
        end
      end
    end
  end
end
