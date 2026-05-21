defmodule WikWeb.PageLive.Components.BlockHistoryModalTest do
  use WikWeb.ConnCase, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias Wik.Accounts.User
  alias WikWeb.PageLive.Components.BlockHistoryModal
  alias Wik.Wiki.PageTree

  test "renders compact revision browser controls and metadata" do
    html =
      render_component(&BlockHistoryModal.render/1, %{
        page_tree: %PageTree{nodes: []},
        placement: %{id: "placement-1", block: %{id: "block-1", type: :markdown}},
        scope: %{tenant: %{name: "space"}},
        selected_text: "hello",
        selected_version: %{
          id: "version-2",
          revision: 2,
          inserted_at: ~U[2026-05-01 15:00:00Z],
          author: %User{id: "user-1", email: "one@example.com"}
        },
        total_versions: 2
      })

    document = LazyHTML.from_fragment(html)

    author = LazyHTML.query(document, testid("block-history-author"))
    author_name = LazyHTML.query(document, testid("block-history-author-name"))
    revision = LazyHTML.query(document, testid("block-history-revision"))
    timestamp = LazyHTML.query(document, testid("block-history-timestamp"))
    first_button = LazyHTML.query(document, testid("block-history-first"))
    prev_button = LazyHTML.query(document, testid("block-history-prev"))
    next_button = LazyHTML.query(document, testid("block-history-next"))
    last_button = LazyHTML.query(document, testid("block-history-last"))

    assert revision
    assert LazyHTML.text(revision) =~ "2/2"
    assert author
    assert author_name
    assert LazyHTML.text(author_name) =~ "one"
    assert timestamp
    assert LazyHTML.to_html(timestamp) =~ "2026-05-01 15:00"
    assert html =~ "hello"
    assert first_button
    assert LazyHTML.to_html(first_button) =~ ~s(phx-value-direction="first")
    assert prev_button
    assert LazyHTML.to_html(prev_button) =~ ~s(phx-value-direction="prev")
    assert next_button
    assert LazyHTML.to_html(next_button) =~ ~s(phx-value-direction="next")
    assert last_button
    assert LazyHTML.to_html(last_button) =~ ~s(phx-value-direction="last")
  end
end
