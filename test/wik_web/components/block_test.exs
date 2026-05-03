defmodule WikWeb.Components.BlockTest do
  use WikWeb.ConnCase, async: true

  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias Wik.Wiki.PageTree
  alias WikWeb.Components.Block

  test "render shows titled block titles" do
    html =
      render_component(&Block.render/1, %{
        placement: %{
          block: %{
            id: "block-1",
            data: %{"title" => "Featured video", "url" => ""},
            type: :youtube
          }
        }
      })

    document = LazyHTML.from_fragment(html)

    assert document |> LazyHTML.query("h2") |> Enum.any?()
    assert html =~ "Featured video"
  end

  test "render hides empty block titles" do
    html =
      render_component(&Block.render/1, %{
        placement: %{
          block: %{
            id: "block-1",
            data: %{"title" => "", "url" => ""},
            type: :youtube
          }
        }
      })

    document = LazyHTML.from_fragment(html)

    refute document |> LazyHTML.query("h2") |> Enum.any?()
  end

  test "form renders title input for titled blocks" do
    html =
      render_component(&Block.form/1, %{
        form: to_form(%{"title" => "", "url" => ""}, as: :block),
        placement: %{
          block: %{
            id: "block-1",
            data: %{"title" => "", "url" => ""},
            type: :youtube
          }
        }
      })

    assert html =~ ~s(id="edit-block-title-block-1")
    assert html =~ ~s(name="block[title]")
  end

  test "form does not render title input for text and markdown blocks" do
    text_html =
      render_component(&Block.form/1, %{
        form: to_form(%{"text" => ""}, as: :block),
        placement: %{block: %{id: "text-block", data: %{"text" => ""}, type: :text}}
      })

    markdown_html =
      render_component(&Block.form/1, %{
        form: to_form(%{"text" => "", "wikilink_map" => "{}"}, as: :block),
        page_tree: %PageTree{nodes: []},
        placement: %{block: %{id: "markdown-block", data: %{"text" => ""}, type: :markdown}}
      })

    refute text_html =~ ~s(name="block[title]")
    refute markdown_html =~ ~s(name="block[title]")
  end
end
