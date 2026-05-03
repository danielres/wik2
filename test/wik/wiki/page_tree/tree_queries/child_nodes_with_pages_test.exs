defmodule Wik.Wiki.PageTree.TreeQueries.ChildNodesWithPagesTest do
  use ExUnit.Case, async: true

  alias Wik.Wiki.PageTree.TreeQueries

  test "returns only direct child nodes that have pages" do
    nodes = [
      %{id: 1, page_id: "parent", parent_id: nil, slug: "docs", title: "Docs"},
      %{id: 2, page_id: "child", parent_id: 1, slug: "guide", title: "Guide"},
      %{id: 3, page_id: nil, parent_id: 1, slug: "draft", title: "Draft"},
      %{id: 4, page_id: "sibling", parent_id: nil, slug: "faq", title: "FAQ"}
    ]

    assert [%{id: 2, title: "Guide"}] = TreeQueries.get_child_nodes_with_pages(nodes, 1)
  end

  test "returns an empty list when no child nodes have pages" do
    nodes = [
      %{id: 1, page_id: "parent", parent_id: nil, slug: "docs", title: "Docs"},
      %{id: 2, page_id: nil, parent_id: 1, slug: "draft", title: "Draft"}
    ]

    assert [] == TreeQueries.get_child_nodes_with_pages(nodes, 1)
  end
end
