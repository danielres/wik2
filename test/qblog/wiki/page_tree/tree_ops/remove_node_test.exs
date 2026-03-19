defmodule Qblog.Wiki.PageTree.TreeOps.RemoveNodeTest do
  use ExUnit.Case, async: true

  alias Qblog.Wiki.PageTree.TreeOps.RemoveNode

  test "removes a leaf root node" do
    nodes = [
      %{
        id: 1,
        page_id: nil,
        parent_id: nil
      }
    ]

    assert {:ok, new_nodes} = RemoveNode.call(nodes, 1)
    assert [] = new_nodes
  end

  test "removes a leaf child node" do
    nodes = [
      %{
        id: 1,
        page_id: nil,
        parent_id: nil
      },
      %{
        id: 2,
        page_id: nil,
        parent_id: 1
      }
    ]

    assert {:ok, new_nodes} = RemoveNode.call(nodes, 2)

    assert [
             %{
               id: 1,
               page_id: nil,
               parent_id: nil
             }
           ] = new_nodes
  end

  test "returns an error when node does not exist" do
    nodes = []

    assert {:error, "node not found"} = RemoveNode.call(nodes, 999)
  end

  test "returns an error when node has children" do
    nodes = [
      %{
        id: 1,
        page_id: nil,
        parent_id: nil
      },
      %{
        id: 2,
        page_id: nil,
        parent_id: 1
      }
    ]

    assert {:error, "cannot remove a node that has children"} =
             RemoveNode.call(nodes, 1)
  end
end
