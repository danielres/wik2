defmodule Qblog.Wiki.PageTree.TreeQueriesTest do
  use ExUnit.Case, async: true

  alias Qblog.Wiki.PageTree.TreeQueries

  test "get_node returns the matching node" do
    nodes = [
      %{id: 1, page_id: nil, parent_id: nil},
      %{id: 2, page_id: nil, parent_id: 1}
    ]

    assert %{id: 2, page_id: nil, parent_id: 1} =
             TreeQueries.get_node(nodes, 2)
  end

  test "get_node returns nil when the node does not exist" do
    nodes = [
      %{id: 1, page_id: nil, parent_id: nil}
    ]

    assert nil == TreeQueries.get_node(nodes, 999)
  end

  test "get_node_by_path finds a node from a list of slugs" do
    nodes = [
      %{id: 1, page_id: nil, parent_id: nil, slug: "docs"},
      %{id: 2, page_id: nil, parent_id: 1, slug: "faq"},
      %{id: 3, page_id: nil, parent_id: nil, slug: "blog"}
    ]

    assert {:ok, %{id: 2, parent_id: 1, slug: "faq"}} =
             TreeQueries.get_node_by_path(nodes, ["docs", "faq"])
  end

  test "get_node_by_path finds a node from a slash path" do
    nodes = [
      %{id: 1, page_id: nil, parent_id: nil, slug: "docs"},
      %{id: 2, page_id: nil, parent_id: 1, slug: "faq"},
      %{id: 3, page_id: nil, parent_id: nil, slug: "blog"}
    ]

    assert {:ok, %{id: 2, parent_id: 1, slug: "faq"}} =
             TreeQueries.get_node_by_path(nodes, "docs/faq")
  end

  test "get_node_by_path returns not_found when the path does not exist" do
    nodes = [
      %{id: 1, page_id: nil, parent_id: nil, slug: "docs"},
      %{id: 2, page_id: nil, parent_id: 1, slug: "faq"}
    ]

    assert {:error, :not_found} == TreeQueries.get_node_by_path(nodes, ["docs", "missing"])
    assert {:error, :not_found} == TreeQueries.get_node_by_path(nodes, "missing")
    assert {:error, :not_found} == TreeQueries.get_node_by_path(nodes, "")
  end

  # TODO: move to TreeOps
  test "create_by_path creates all missing nodes for a slash path" do
    nodes = [
      %{id: 1, page_id: nil, parent_id: nil, slug: "docs", title: "Docs"}
    ]

    assert {:ok, %{id: 3, parent_id: 2, slug: "install", title: "Install", page_id: "page-1"},
            nodes} =
             TreeQueries.create_by_path(nodes, "docs/guides/install", %{
               title: "Install",
               page_id: "page-1"
             })

    assert [
             %{id: 1, parent_id: nil, slug: "docs", title: "Docs", page_id: nil},
             %{id: 2, parent_id: 1, slug: "guides", title: "Guides", page_id: nil},
             %{id: 3, parent_id: 2, slug: "install", title: "Install", page_id: "page-1"}
           ] = nodes
  end

  # TODO: move to TreeOps
  test "create_by_path accepts a list path and reuses existing segments" do
    nodes = [
      %{id: 1, page_id: nil, parent_id: nil, slug: "docs", title: "Docs"},
      %{id: 2, page_id: nil, parent_id: 1, slug: "guides", title: "Guides"}
    ]

    assert {:ok, %{id: 3, parent_id: 2, slug: "install", title: "Install", page_id: nil}, nodes} =
             TreeQueries.create_by_path(nodes, ["docs", "guides", "install"], %{title: "Install"})

    assert [
             %{id: 1, parent_id: nil, slug: "docs", title: "Docs", page_id: nil},
             %{id: 2, parent_id: 1, slug: "guides", title: "Guides", page_id: nil},
             %{id: 3, parent_id: 2, slug: "install", title: "Install", page_id: nil}
           ] = nodes
  end

  # TODO: move to TreeOps
  test "create_by_path returns the existing leaf without changing it" do
    nodes = [
      %{id: 1, page_id: nil, parent_id: nil, slug: "docs", title: "Docs"},
      %{id: 2, page_id: "page-1", parent_id: 1, slug: "install", title: "Install"}
    ]

    assert {:ok, %{id: 2, page_id: "page-1", parent_id: 1, slug: "install", title: "Install"},
            ^nodes} =
             TreeQueries.create_by_path(nodes, "docs/install", %{
               title: "Ignored",
               page_id: "page-2"
             })
  end

  # TODO: move to TreeOps
  test "create_by_path rejects invalid attrs and invalid paths" do
    nodes = []

    assert {:error, :invalid_attrs} == TreeQueries.create_by_path(nodes, "docs", %{})

    assert {:error, :invalid_attrs} ==
             TreeQueries.create_by_path(nodes, "docs", %{title: "Docs", extra: true})

    assert {:error, :invalid_path} == TreeQueries.create_by_path(nodes, "", %{title: "Docs"})

    assert {:error, :invalid_path} ==
             TreeQueries.create_by_path(nodes, ["docs", ""], %{title: "Docs"})
  end

  test "root_nodes returns all nodes with nil parent_id" do
    nodes = [
      %{id: 1, page_id: nil, parent_id: nil},
      %{id: 2, page_id: nil, parent_id: 1},
      %{id: 3, page_id: nil, parent_id: nil}
    ]

    assert [
             %{id: 1, page_id: nil, parent_id: nil},
             %{id: 3, page_id: nil, parent_id: nil}
           ] = TreeQueries.root_nodes(nodes)
  end

  test "child_nodes returns all direct children of a node" do
    nodes = [
      %{id: 1, page_id: nil, parent_id: nil},
      %{id: 2, page_id: nil, parent_id: 1},
      %{id: 3, page_id: nil, parent_id: 1},
      %{id: 4, page_id: nil, parent_id: 2}
    ]

    assert [
             %{id: 2, page_id: nil, parent_id: 1},
             %{id: 3, page_id: nil, parent_id: 1}
           ] = TreeQueries.child_nodes(nodes, 1)
  end

  test "child_nodes returns an empty list when a node has no children" do
    nodes = [
      %{id: 1, page_id: nil, parent_id: nil},
      %{id: 2, page_id: nil, parent_id: 1}
    ]

    assert [] == TreeQueries.child_nodes(nodes, 2)
  end

  test "leaf? returns true when a node has no children" do
    nodes = [
      %{id: 1, page_id: nil, parent_id: nil},
      %{id: 2, page_id: nil, parent_id: 1}
    ]

    assert true == TreeQueries.leaf?(nodes, 2)
  end

  test "leaf? returns false when a node has children" do
    nodes = [
      %{id: 1, page_id: nil, parent_id: nil},
      %{id: 2, page_id: nil, parent_id: 1}
    ]

    assert false == TreeQueries.leaf?(nodes, 1)
  end
end
