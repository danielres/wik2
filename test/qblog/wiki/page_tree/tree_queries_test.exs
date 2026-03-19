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
