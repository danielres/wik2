defmodule QblogWeb.Components.Block.Types.MarkdownTest do
  use QblogWeb.ConnCase, async: true

  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias QblogWeb.Components.Block.Types.Markdown

  test "render converts markdown to html" do
    html =
      render_component(&Markdown.render/1, %{
        block: %{data: %{"text" => "## Title\n\n- One\n- Two"}}
      })

    document = LazyHTML.from_fragment(html)

    assert document |> LazyHTML.filter("h2") |> Enum.any?()
    assert document |> LazyHTML.filter("ul li") |> Enum.count() == 2
  end

  test "render escapes raw html" do
    html =
      render_component(&Markdown.render/1, %{
        block: %{data: %{"text" => "<script>alert('xss')</script>"}}
      })

    document = LazyHTML.from_fragment(html)

    refute document |> LazyHTML.filter("script") |> Enum.any?()
    assert html =~ "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"
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
