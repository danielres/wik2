defmodule WikWeb.AuthController.Dev do
  use WikWeb, :controller

  @dev_routes? Application.compile_env(:wik, :dev_routes, false)

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.DevAuth

  require Logger

  def create(conn, params) do
    if @dev_routes? do
      case dev_sign_in_user_id(params) do
        nil -> sign_in_superadmin(conn)
        user_id -> sign_in_existing_user(conn, user_id)
      end
    else
      raise "dev auth route is only available when :dev_routes is enabled"
    end
  end

  defp sign_in_existing_user(conn, user_id) do
    with {:ok, user} <- DevAuth.sign_in_user(user_id),
         {:ok, conn} <- sign_in_user(conn, user) do
      conn
    else
      {:error, error} ->
        Logger.error("Dev authentication failed: #{inspect(error)}")

        conn
        |> redirect(to: ~p"/sign-in")
    end
  end

  defp sign_in_superadmin(conn) do
    with {:ok, user} <- DevAuth.sign_in_superadmin(),
         {:ok, conn} <- sign_in_user(conn, user) do
      conn
    else
      {:error, error} ->
        Logger.error("Dev authentication failed: #{inspect(error)}")

        conn
        |> redirect(to: ~p"/sign-in")
    end
  end

  defp sign_in_user(conn, user) do
    with {:ok, token, _claims} <- Jwt.token_for_user(user) do
      return_to = get_session(conn, :return_to) || ~p"/"
      user = Ash.Resource.set_metadata(user, %{token: token})

      {:ok,
       conn
       |> delete_session(:return_to)
       |> AuthHelpers.store_in_session(user)
       |> assign(:current_user, user)
       |> redirect(to: return_to)}
    end
  end

  defp dev_sign_in_user_id(%{"dev_sign_in" => %{"user_id" => user_id}}) when user_id != "",
    do: user_id

  defp dev_sign_in_user_id(%{"user_id" => user_id}) when user_id != "", do: user_id
  defp dev_sign_in_user_id(_params), do: nil
end
