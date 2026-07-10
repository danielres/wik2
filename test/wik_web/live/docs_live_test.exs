defmodule WikWeb.DocsLiveTest do
  use WikWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the docs home page", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/docs")

    assert has_element?(view, ~s([data-testid="docs-page-index"]))
  end

  test "renders the core features page", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/docs/core-features")

    assert has_element?(view, ~s([data-testid="docs-page-core-features"]))
  end
end
