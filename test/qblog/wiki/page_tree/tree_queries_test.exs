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

  test "get_node_parent returns the parent node" do
    nodes = [
      %{id: 1, page_id: nil, parent_id: nil},
      %{id: 2, page_id: nil, parent_id: 1}
    ]

    assert %{id: 1, page_id: nil, parent_id: nil} == TreeQueries.get_node_parent(nodes, 2)
  end

  test "get_node_ancestors returns the node ancestors" do
    nodes = [
      %{id: 1, page_id: nil, parent_id: nil},
      %{id: 2, page_id: nil, parent_id: 1},
      %{id: 3, page_id: nil, parent_id: 2},
      %{id: 4, page_id: nil, parent_id: 2}
    ]

    assert [
             %{id: 3, page_id: nil, parent_id: 2},
             %{id: 2, page_id: nil, parent_id: 1},
             %{id: 1, page_id: nil, parent_id: nil}
           ] == TreeQueries.get_node_ancestors(nodes, 3)
  end

  test "get_node_path_segments returns the node path as a list of slugs" do
    nodes = [
      %{id: 1, page_id: nil, parent_id: nil, slug: "docs"},
      %{id: 2, page_id: nil, parent_id: 1, slug: "faq"},
      %{id: 3, page_id: nil, parent_id: 2, slug: "install"}
    ]

    assert ["docs", "faq", "install"] == TreeQueries.get_node_path_segments(nodes, 3)
  end

  test "get_node_path returns the node path as a string" do
    nodes = [
      %{id: 1, page_id: nil, parent_id: nil, slug: "docs"},
      %{id: 2, page_id: nil, parent_id: 1, slug: "faq"},
      %{id: 3, page_id: nil, parent_id: 2, slug: "install"}
    ]

    assert "docs/faq/install" == TreeQueries.get_node_path(nodes, 3)
  end

  test "get_descendant_ids returns all nested descendants" do
    nodes = [
      %{id: 1, page_id: nil, parent_id: nil, slug: "home"},
      %{id: 2, page_id: nil, parent_id: 1, slug: "about"},
      %{id: 3, page_id: nil, parent_id: 2, slug: "faq"},
      %{id: 4, page_id: nil, parent_id: 1, slug: "docs"}
    ]

    assert [2, 4, 3] == TreeQueries.get_descendant_ids(nodes, 1)
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
           ] = TreeQueries.get_child_nodes(nodes, 1)
  end

  test "child_nodes returns an empty list when a node has no children" do
    nodes = [
      %{id: 1, page_id: nil, parent_id: nil},
      %{id: 2, page_id: nil, parent_id: 1}
    ]

    assert [] == TreeQueries.get_child_nodes(nodes, 2)
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

  test "get_valid_parent_nodes rejects the current node, its parent, descendants, and parents with a matching child slug" do
    nodes = [
      %{id: 1, parent_id: nil, slug: "home", title: "Home"},
      %{id: 2, parent_id: 1, slug: "about", title: "About"},
      %{id: 3, parent_id: nil, slug: "docs", title: "Docs"},
      %{id: 4, parent_id: 3, slug: "about", title: "About"},
      %{id: 5, parent_id: nil, slug: "blog", title: "Blog"},
      %{id: 6, parent_id: 2, slug: "faq", title: "Faq"}
    ]

    assert [4, 5] == node_ids(TreeQueries.get_valid_parent_nodes(nodes, 2))
  end

  test "get_valid_parent_nodes keeps parents whose direct children use a different slug" do
    nodes = [
      %{id: 1, parent_id: nil, slug: "home", title: "Home"},
      %{id: 2, parent_id: 1, slug: "about", title: "About"},
      %{id: 3, parent_id: nil, slug: "docs", title: "Docs"},
      %{id: 4, parent_id: 3, slug: "faq", title: "Faq"},
      %{id: 5, parent_id: nil, slug: "blog", title: "Blog"}
    ]

    assert [3, 4, 5] == node_ids(TreeQueries.get_valid_parent_nodes(nodes, 2))
  end

  test "get_valid_parent_nodes rejects top level when a root node already uses the same slug" do
    nodes = [
      %{id: 1, parent_id: nil, slug: "home", title: "Home"},
      %{id: 2, parent_id: 1, slug: "about", title: "About"},
      %{id: 3, parent_id: nil, slug: "about", title: "About"},
      %{id: 4, parent_id: nil, slug: "blog", title: "Blog"}
    ]

    assert [3, 4] == node_ids(TreeQueries.get_valid_parent_nodes(nodes, 2))
  end

  defp node_ids(nodes), do: Enum.map(nodes, & &1.id)
end
