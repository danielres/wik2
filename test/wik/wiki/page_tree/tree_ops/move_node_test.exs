defmodule Wik.Wiki.PageTree.TreeOps.MoveNodeTest do
  use ExUnit.Case, async: true

  alias Wik.Wiki.PageTree.TreeOps.MoveNode

  test "moves a node to root" do
    nodes = [
      %{id: 1, parent_id: nil, page_id: nil},
      %{id: 2, parent_id: 1, page_id: nil}
    ]

    assert {:ok, new_nodes} = MoveNode.call(nodes, 2, nil)

    assert Enum.any?(new_nodes, &(&1.id == 2 and is_nil(&1.parent_id)))
  end

  test "moves a node under another node" do
    nodes = [
      %{id: 1, parent_id: nil, page_id: nil},
      %{id: 2, parent_id: nil, page_id: nil}
    ]

    assert {:ok, new_nodes} = MoveNode.call(nodes, 2, 1)

    assert Enum.any?(new_nodes, &(&1.id == 2 and &1.parent_id == 1))
  end

  test "fails if node does not exist" do
    assert {:error, "node not found"} = MoveNode.call([], 1, nil)
  end

  test "fails if new parent does not exist" do
    nodes = [%{id: 1, parent_id: nil, page_id: nil}]

    assert {:error, "new parent not found"} =
             MoveNode.call(nodes, 1, 999)
  end

  test "fails on self-parenting" do
    nodes = [%{id: 1, parent_id: nil, page_id: nil}]

    assert {:error, "cannot move a node under itself"} =
             MoveNode.call(nodes, 1, 1)
  end

  test "fails on cycle (move under descendant)" do
    nodes = [
      %{id: 1, parent_id: nil, page_id: nil},
      %{id: 2, parent_id: 1, page_id: nil},
      %{id: 3, parent_id: 2, page_id: nil}
    ]

    assert {:error, "cannot move a node under its descendant"} =
             MoveNode.call(nodes, 1, 3)
  end
end
