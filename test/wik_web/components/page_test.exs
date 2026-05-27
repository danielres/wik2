defmodule WikWeb.Components.PageTest do
  use WikWeb.ConnCase, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias Wik.Scope
  alias Wik.Wiki.PageTree
  alias Wik.Wiki.PageTree.Node
  alias WikWeb.Components.Page

  test "breadcrumbs renders ancestor and current page links" do
    html =
      render_component(&Page.breadcrumbs/1, %{
        node: %{id: 3},
        page_tree: page_tree_fixture(),
        scope: %Scope{actor: %{id: "user-1"}, tenant: %{slug: "cool-stuff"}}
      })

    document = LazyHTML.from_fragment(html)

    assert document |> LazyHTML.query(~s(a[href="/cool-stuff/wiki/recipes"])) |> Enum.any?()
    assert document |> LazyHTML.query(~s(a[href="/cool-stuff/wiki/recipes/cakes"])) |> Enum.any?()

    assert document
           |> LazyHTML.query(~s(a[href="/cool-stuff/wiki/recipes/cakes/cheesecake"]))
           |> Enum.any?()
  end

  test "breadcrumbs can omit the current page and keep a trailing separator" do
    html =
      render_component(&Page.breadcrumbs/1, %{
        include_current?: false,
        trailing_separator?: true,
        node: %{id: 3},
        page_tree: page_tree_fixture(),
        scope: %Scope{actor: %{id: "user-1"}, tenant: %{slug: "cool-stuff"}}
      })

    assert html =~ ~s(href="/cool-stuff/wiki/recipes")
    assert html =~ ~s(href="/cool-stuff/wiki/recipes/cakes")
    refute html =~ ~s(href="/cool-stuff/wiki/recipes/cakes/cheesecake")
    assert html =~ ">"
  end

  defp page_tree_fixture do
    %PageTree{
      nodes: [
        %Node{id: 1, page_id: "page-1", parent_id: nil, slug: "recipes", title: "Recipes"},
        %Node{id: 2, page_id: "page-2", parent_id: 1, slug: "cakes", title: "Cakes"},
        %Node{id: 3, page_id: "page-3", parent_id: 2, slug: "cheesecake", title: "Cheesecake"}
      ]
    }
  end
end
