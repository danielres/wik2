defmodule QblogWeb.PageLive.Components.BlockHistoryModalTest do
  use QblogWeb.ConnCase, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias Qblog.Accounts.User
  alias QblogWeb.PageLive.Components.BlockHistoryModal
  alias Qblog.Wiki.PageTree

  test "renders compact revision browser controls and metadata" do
    html =
      render_component(&BlockHistoryModal.render/1, %{
        page_tree: %PageTree{nodes: []},
        placement: %{id: "placement-1", block: %{id: "block-1", type: :markdown}},
        scope: %{tenant: %{name: "group"}},
        selected_text: "hello",
        selected_version_id: "version-2",
        versions: [
          %{
            id: "version-2",
            revision: 2,
            inserted_at: ~U[2026-05-01 15:00:00Z],
            author: %User{id: "user-1", email: "one@example.com"}
          },
          %{
            id: "version-1",
            revision: 1,
            inserted_at: ~U[2026-05-01 14:00:00Z],
            author: %User{id: "user-2", email: "two@example.com"}
          }
        ]
      })

    document = LazyHTML.from_fragment(html)

    author = LazyHTML.query(document, testid("block-history-author"))
    metadata = LazyHTML.query(document, testid("block-history-metadata"))
    revision = LazyHTML.query(document, testid("block-history-revision"))
    first_button = LazyHTML.query(document, testid("block-history-first"))
    prev_button = LazyHTML.query(document, testid("block-history-prev"))
    next_button = LazyHTML.query(document, testid("block-history-next"))
    last_button = LazyHTML.query(document, testid("block-history-last"))

    assert revision
    assert LazyHTML.text(revision) =~ "2/2"
    assert author
    assert LazyHTML.text(author) =~ "one"
    assert metadata
    assert LazyHTML.text(metadata) =~ "2026-05-01 15:00"
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
