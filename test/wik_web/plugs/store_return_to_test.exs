defmodule WikWeb.Plugs.StoreReturnToTest do
  use WikWeb.ConnCase

  alias WikWeb.Plugs.StoreReturnTo

  test "stores return_to for anonymous GET requests", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{})
      |> Map.put(:method, "GET")
      |> Map.put(:request_path, "/space/wiki/home")
      |> Map.put(:query_string, "tab=activity")
      |> StoreReturnTo.call([])

    assert get_session(conn, :return_to) == "/space/wiki/home?tab=activity"
  end

  test "does not store return_to for anonymous non-GET requests", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{return_to: "/existing"})
      |> Map.put(:method, "POST")
      |> Map.put(:request_path, "/space/wiki/home")
      |> Map.put(:query_string, "")
      |> StoreReturnTo.call([])

    assert get_session(conn, :return_to) == "/existing"
  end

  test "does not overwrite return_to for authenticated requests", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{return_to: "/existing"})
      |> Plug.Conn.assign(:current_user, %{id: "user-id"})
      |> Map.put(:method, "GET")
      |> Map.put(:request_path, "/space/wiki/home")
      |> Map.put(:query_string, "")
      |> StoreReturnTo.call([])

    assert get_session(conn, :return_to) == "/existing"
  end
end
