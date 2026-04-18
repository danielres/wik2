defmodule QblogWeb.Components.Block.Types.MarkdownTest do
  use QblogWeb.ConnCase, async: true

  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias QblogWeb.Components.Block.Types.Markdown

  test "render converts markdown to html" do
    html =
      render_component(&Markdown.render/1, %{
        block: %{id: "block-1", data: %{"text" => "## Title\n\n- One\n- Two"}}
      })

    assert html =~ "<h2>Title</h2>"
    assert html =~ "<ul><li>One</li><li>Two</li></ul>"
  end

  test "render converts wikilinks to wiki page links" do
    html =
      render_component(&Markdown.render/1, %{
        block: %{id: "block-1", data: %{"text" => "[[recipes]] and [[recipes/soup]]"}},
        scope: %{tenant: %{name: "cool-stuff"}}
      })

    assert html =~ ~s(href="/cool-stuff/wiki/recipes")
    assert html =~ ~s(href="/cool-stuff/wiki/recipes/soup")
  end

  test "render sanitizes unsafe html" do
    html =
      render_component(&Markdown.render/1, %{
        block: %{
          id: "block-1",
          data: %{"text" => "<script>alert('xss')</script><img src=x onerror=alert(1)>"}
        }
      })

    document = LazyHTML.from_fragment(html)

    refute document |> LazyHTML.filter("script") |> Enum.any?()
    refute document |> LazyHTML.filter("img") |> Enum.any?()
    refute html =~ "onerror"
    assert html =~ "alert('xss')"
  end

  test "form_fields keeps the markdown source editable" do
    html =
      render_component(&Markdown.form_fields/1, %{
        block: %{id: "block-1", data: %{"text" => "## Title"}},
        form: to_form(%{"text" => "## Title"}, as: :block)
      })

    assert html =~ ~s(id="edit-block-markdown-textarea-block-1")
    assert html =~ ~s(name="block[text]")
    assert html =~ "## Title"
  end
end
