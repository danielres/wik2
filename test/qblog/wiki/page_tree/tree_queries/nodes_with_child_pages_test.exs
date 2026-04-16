defmodule Qblog.Wiki.PageTree.TreeQueries.NodesWithChildPagesTest do
  use ExUnit.Case, async: true

  alias Qblog.Wiki.PageTree.TreeQueries

  test "returns only page-backed nodes that have child nodes with pages" do
    nodes = [
      %{id: 1, page_id: "home", parent_id: nil, slug: "home", title: "Home"},
      %{id: 2, page_id: "docs", parent_id: nil, slug: "docs", title: "Docs"},
      %{id: 3, page_id: "guide", parent_id: 2, slug: "guide", title: "Guide"},
      %{id: 4, page_id: nil, parent_id: 2, slug: "draft", title: "Draft"},
      %{id: 5, page_id: "faq", parent_id: nil, slug: "faq", title: "FAQ"}
    ]

    assert [%{id: 2, title: "Docs"}] = TreeQueries.get_nodes_with_child_pages(nodes)
  end
end
