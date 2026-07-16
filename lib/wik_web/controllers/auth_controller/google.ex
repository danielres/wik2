defmodule WikWeb.AuthController.Google do
  use WikWeb, :controller

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Access
  alias Wik.Access.Google.Provider, as: Google
  alias WikWeb.GoogleAvatarCache

  require Logger

  def request(conn, params) do
    return_to = (params["return_to"] || get_session(conn, :return_to)) |> validate_return_to()

    case Google.authorize_url(callback_url()) do
      {:ok, %{url: url, session_params: session_params}} ->
        conn
        |> put_session(:google_return_to, return_to)
        |> put_session(:google_session_params, session_params)
        |> redirect(external: url)

      {:error, _error} ->
        Logger.error("Google authorization request failed: google_authorize_error")

        conn
        |> put_flash(:error, "Google sign in is not available")
        |> redirect(to: ~p"/sign-in")
    end
  end

  def callback(conn, params) do
    session_params = get_session(conn, :google_session_params) || %{}
    return_to = get_session(conn, :google_return_to) |> validate_return_to()

    with {:ok, %{user: google_user}} <- Google.callback(params, session_params, callback_url()),
         :ok <- require_verified_email(google_user),
         {:ok, %{user: user}} <- Access.google_find_or_create_identity(google_user),
         {:ok, _grants} <- Access.google_apply_email_access(user),
         {:ok, token, _claims} <- Jwt.token_for_user(user) do
      refresh_avatar(google_user)

      user = Ash.Resource.set_metadata(user, %{token: token})

      conn
      |> delete_session(:return_to)
      |> delete_session(:google_return_to)
      |> delete_session(:google_session_params)
      |> AuthHelpers.store_in_session(user)
      |> assign(:current_user, user)
      |> redirect(to: return_to)
    else
      {:error, :google_email_rule_not_found} ->
        conn
        |> delete_session(:google_return_to)
        |> delete_session(:google_session_params)
        |> put_flash(:error, "Your Google account has not been granted access to any spaces")
        |> redirect(to: ~p"/sign-in")

      {:error, _error} ->
        Logger.error("Google authentication failed: google_callback_error")

        conn
        |> delete_session(:google_return_to)
        |> delete_session(:google_session_params)
        |> put_flash(:error, "Google authentication failed")
        |> redirect(to: ~p"/sign-in")
    end
  end

  defp callback_url, do: url(~p"/auth/google/callback")

  defp refresh_avatar(%{"picture" => picture}) when is_binary(picture) do
    _result = Task.start(fn -> GoogleAvatarCache.refresh(picture) end)
    :ok
  end

  defp refresh_avatar(_google_user), do: :ok

  defp require_verified_email(google_user) do
    if Google.verified_email?(google_user) do
      :ok
    else
      {:error, :google_email_unverified}
    end
  end

  defp validate_return_to(path) when is_binary(path) do
    uri = URI.parse(path)

    cond do
      not String.starts_with?(path, "/") -> ~p"/"
      String.starts_with?(path, "//") -> ~p"/"
      unsafe_return_path?(path) -> ~p"/"
      uri.host != nil -> ~p"/"
      uri.scheme != nil -> ~p"/"
      true -> path
    end
  end

  defp validate_return_to(_path), do: ~p"/"

  defp unsafe_return_path?(path) do
    String.contains?(path, "\\") or Regex.match?(~r/[\x00-\x1F\x7F]/, path)
  end
end
