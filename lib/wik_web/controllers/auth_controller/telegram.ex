defmodule WikWeb.AuthController.Telegram do
  use WikWeb, :controller

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Access
  alias Wik.Access.Telegram.Provider, as: Telegram
  alias WikWeb.Auth.ReturnTo

  require Logger

  def callback(conn, params) do
    return_to = params["return_to"] |> ReturnTo.validate()
    params = Map.delete(params, "return_to")

    with {:ok, %{user: telegram_user}} <- Telegram.verify_login(params),
         {:ok, %{user: user}} <- Access.telegram_find_or_create_identity(telegram_user),
         {:ok, _grants} <- Access.telegram_refresh_grants(user),
         {:ok, token, _claims} <- Jwt.token_for_user(user) do
      user = Ash.Resource.set_metadata(user, %{token: token})

      conn
      |> delete_session(:return_to)
      |> AuthHelpers.store_in_session(user)
      |> assign(:current_user, user)
      |> redirect(to: return_to)
    else
      {:error, error} ->
        Logger.error("Telegram authentication failed: #{inspect(error)}")

        conn
        |> put_flash(:error, "Telegram authentication failed")
        |> redirect(to: ~p"/sign-in")
    end
  end
end
