defmodule QblogWeb.Components.Block.Types.MarkdownTest do
  use QblogWeb.ConnCase, async: true

  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias Qblog.Scope
  alias QblogWeb.Components.Block.Types.Markdown
  alias Qblog.Wiki.PageTree
  alias Qblog.Wiki.PageTree.Node

  test "render converts markdown to html" do
    html =
      render_component(&Markdown.render/1, %{
        block: %{id: "block-1", data: %{"text" => "## Title\n\n- One\n- Two"}},
        page_tree: %PageTree{nodes: []}
      })

    document = LazyHTML.from_fragment(html)

    assert document |> LazyHTML.query("h2") |> Enum.any?()
    assert document |> LazyHTML.query("ul li") |> Enum.count() == 2
  end

  test "render converts canonical wikilinks to wiki page links" do
    page_tree = page_tree_fixture()
    scope = %Scope{tenant: %{name: "cool-stuff"}}

    html =
      render_component(&Markdown.render/1, %{
        block: %{id: "block-1", data: %{"text" => "[[node:1]] and [[node:2]]"}},
        page_tree: page_tree,
        scope: scope
      })

    document = LazyHTML.from_fragment(html)

    assert document
           |> LazyHTML.query(~s(a[href="/#{scope.tenant.name}/wiki/recipes"]))
           |> Enum.any?()

    assert document
           |> LazyHTML.query(~s(a[href="/#{scope.tenant.name}/wiki/recipes/soup"]))
           |> Enum.any?()
  end

  test "render patches canonical wikilinks through the current LiveView" do
    page_tree = page_tree_fixture()
    scope = %Scope{tenant: %{name: "cool-stuff"}}

    html =
      render_component(&Markdown.render/1, %{
        block: %{id: "block-1", data: %{"text" => "[[node:1]]"}},
        page_tree: page_tree,
        scope: scope
      })

    document = LazyHTML.from_fragment(html)

    assert document
           |> LazyHTML.query(
             ~s(a[href="/#{scope.tenant.name}/wiki/recipes"][data-phx-link="patch"][data-phx-link-state="push"])
           )
           |> Enum.any?()
  end

  test "render opens external links in a new tab" do
    html =
      render_component(&Markdown.render/1, %{
        block: %{id: "block-1", data: %{"text" => "[Phoenix](https://phoenixframework.org)"}},
        page_tree: %PageTree{nodes: []}
      })

    document = LazyHTML.from_fragment(html)

    assert document
           |> LazyHTML.query(
             ~s(a[href="https://phoenixframework.org"][target="_blank"][rel="noopener noreferrer"])
           )
           |> Enum.any?()
  end

  test "render does not open internal wiki links in a new tab" do
    page_tree = page_tree_fixture()
    scope = %Scope{tenant: %{name: "cool-stuff"}}

    html =
      render_component(&Markdown.render/1, %{
        block: %{id: "block-1", data: %{"text" => "[[node:1]]"}},
        page_tree: page_tree,
        scope: scope
      })

    document = LazyHTML.from_fragment(html)

    assert document
           |> LazyHTML.query(~s(a[href="/#{scope.tenant.name}/wiki/recipes"]))
           |> Enum.any?()

    refute document
           |> LazyHTML.query(~s(a[href="/#{scope.tenant.name}/wiki/recipes"][target="_blank"]))
           |> Enum.any?()
  end

  test "render sanitizes unsafe html" do
    html =
      render_component(&Markdown.render/1, %{
        block: %{
          id: "block-1",
          data: %{"text" => "<script>alert('xss')</script><img src=x onerror=alert(1)>"}
        },
        page_tree: %PageTree{nodes: []}
      })

    document = LazyHTML.from_fragment(html)

    refute document |> LazyHTML.query("script") |> Enum.any?()
    refute document |> LazyHTML.query("img") |> Enum.any?()
  end

  test "form_fields keeps the markdown source editable" do
    wikilink_map = Jason.encode!(%{"recipes" => 1, "recipes/soup" => 2})

    html =
      render_component(&Markdown.form_fields/1, %{
        block: %{id: "block-1", data: %{"text" => "## Title"}},
        form: to_form(%{"text" => "## Title", "wikilink_map" => wikilink_map}, as: :block),
        page_tree: page_tree_fixture()
      })

    assert html =~ ~s(id="edit-block-markdown-textarea-block-1")
    assert html =~ ~s(name="block[text]")
    assert html =~ ~s(name="block[wikilink_map]")
    assert html =~ ~s(data-wikilink-paths=)
    assert html =~ "## Title"
    assert html =~ "&quot;recipes&quot;:1"
    assert html =~ "&quot;recipes/soup&quot;:2"
  end

  defp page_tree_fixture do
    %PageTree{
      nodes: [
        %Node{
          id: 1,
          page_id: "11111111-1111-1111-1111-111111111111",
          parent_id: nil,
          slug: "recipes",
          title: "Recipes"
        },
        %Node{
          id: 2,
          page_id: "22222222-2222-2222-2222-222222222222",
          parent_id: 1,
          slug: "soup",
          title: "Soup"
        }
      ]
    }
  end
end
