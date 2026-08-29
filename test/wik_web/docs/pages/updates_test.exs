defmodule WikWeb.Docs.Pages.UpdatesTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias Wik.Updates.Update
  alias WikWeb.Docs.Pages.Updates

  test "renders an update for end users" do
    html =
      render_component(&Updates.render/1, %{
        updates: [
          %Update{
            merged_on: ~D[2026-08-28],
            pr_number: 73,
            sections: [
              %{
                category: "new_features",
                items: ["Calendar events can now be matched to topics automatically."]
              }
            ]
          }
        ]
      })

    document = LazyHTML.from_fragment(html)
    update = LazyHTML.query(document, "#update-73")

    assert Enum.any?(update)
    assert LazyHTML.text(update) =~ "Update #73"
    assert LazyHTML.text(update) =~ "Fri, Aug 28 2026"
    assert LazyHTML.text(update) =~ "New features"
    assert LazyHTML.text(update) =~ "Calendar events can now be matched to topics automatically."

    assert document
           |> LazyHTML.query(
             ~s(a#update-73-pull-request[href="https://github.com/danielres/wik2/pull/73"])
           )
           |> Enum.any?()
  end
end
