defmodule WikWeb.DocsLiveTest do
  use WikWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the docs home page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/docs")

    assert html =~ "What is Wik?"
  end

  test "renders the core features page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/docs/core-features")

    assert html =~ "Core features"
  end
end
