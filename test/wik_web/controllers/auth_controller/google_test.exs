defmodule WikWeb.AuthController.GoogleTest do
  use WikWeb.ConnCase

  setup do
    old_client_id = System.get_env("GOOGLE_CLIENT_ID")
    old_client_secret = System.get_env("GOOGLE_CLIENT_SECRET")
    System.put_env("GOOGLE_CLIENT_ID", "google-client-id")
    System.put_env("GOOGLE_CLIENT_SECRET", "google-client-secret")

    on_exit(fn ->
      restore_env("GOOGLE_CLIENT_ID", old_client_id)
      restore_env("GOOGLE_CLIENT_SECRET", old_client_secret)
    end)
  end

  test "starts Google OAuth and stores session params", %{conn: conn} do
    conn = get(conn, ~p"/auth/google", %{"return_to" => "/me"})

    assert redirected_to(conn) =~ "https://accounts.google.com/o/oauth2/v2/auth"
    assert get_session(conn, :google_return_to) == "/me"
    assert get_session(conn, :google_session_params)[:state] |> is_binary()
  end

  test "prevents open redirects at OAuth start", %{conn: conn} do
    conn = get(conn, ~p"/auth/google", %{"return_to" => "https://evil.example"})

    assert get_session(conn, :google_return_to) == "/"
  end

  test "prevents redirect smuggling at OAuth start", %{conn: conn} do
    backslash_conn = get(conn, ~p"/auth/google", %{"return_to" => "/\\evil.example"})
    control_conn = get(conn, ~p"/auth/google", %{"return_to" => "/me\nLocation: //evil.example"})

    assert get_session(backslash_conn, :google_return_to) == "/"
    assert get_session(control_conn, :google_return_to) == "/"
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
