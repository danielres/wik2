defmodule QblogWeb.AuthController.Dev do
  use QblogWeb, :controller

  @dev_routes? Application.compile_env(:qblog, :dev_routes, false)

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Qblog.DevAuth

  require Logger

  def create(conn, _params) do
    if @dev_routes? do
      sign_in_superadmin(conn)
    else
      raise "dev auth route is only available when :dev_routes is enabled"
    end
  end

  defp sign_in_superadmin(conn) do
    with {:ok, user} <- DevAuth.sign_in_superadmin(),
         {:ok, token, _claims} <- Jwt.token_for_user(user) do
      user = Ash.Resource.set_metadata(user, %{token: token})

      conn
      |> AuthHelpers.store_in_session(user)
      |> assign(:current_user, user)
      |> redirect(to: ~p"/")
    else
      {:error, error} ->
        Logger.error("Dev authentication failed: #{inspect(error)}")

        conn
        |> redirect(to: ~p"/sign-in")
    end
  end
end
