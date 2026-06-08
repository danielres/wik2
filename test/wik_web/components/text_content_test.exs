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

    refute html =~ "<div><br>"
    refute html =~ "<br></div>"
    refute html =~ "<br><br><br>"
    assert html =~ "Body<br><br><a"
    assert html =~ ~s(href="https://example.test")
  end

  test "does not preserve template indentation around html content" do
    html =
      render_component(&TextContent.render/1, %{
        text: "<p>Body</p>"
      })

    refute html =~ ~s(class="whitespace-pre-wrap [&amp;_a])
    assert html =~ ~s(<div class="whitespace-pre-wrap"><p>Body</p></div>)
  end
end
