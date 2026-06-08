defmodule WikWeb.Components.TextContentTest do
  use WikWeb.ConnCase, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias WikWeb.Components.TextContent

  test "normalizes leading trailing and repeated html breaks" do
    html =
      render_component(&TextContent.render/1, %{
        text:
          "<br>Body<br><br><br><br><a href=\"https://example.test\">https://example.test</a><br>"
      })

    document = LazyHTML.from_fragment(html)

    assert document |> LazyHTML.query(~s(a[href="https://example.test"])) |> Enum.any?()
    assert document |> LazyHTML.query("br") |> Enum.count() == 2
  end

  test "does not preserve template indentation around html content" do
    html =
      render_component(&TextContent.render/1, %{
        text: "<p>Body</p>"
      })

    refute html =~ ~s(class="whitespace-pre-wrap [&amp;_a])
    assert html =~ ~s(<div class="whitespace-pre-wrap"><p>Body</p></div>)
  end

  test "links bare www domains in plain text" do
    html =
      render_component(&TextContent.render/1, %{
        text: "More info at www.example.de"
      })

    assert html =~ ~s(href="https://www.example.de")
    assert html =~ ">www.example.de</a>"
  end
end
