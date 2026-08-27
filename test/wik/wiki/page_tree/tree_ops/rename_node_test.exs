defmodule Wik.Wiki.PageTree.TreeOps.RenameNodeTest do
  use ExUnit.Case, async: true

  alias Wik.Wiki.PageTree.TreeOps.RenameNode

  test "renames the selected node without changing its placement or page" do
    nodes = [
      %{id: 1, page_id: "page-id", parent_id: nil, slug: "home", title: "Home"},
      %{id: 2, page_id: nil, parent_id: 1, slug: "notes", title: "Notes"}
    ]

    assert {:ok, renamed_nodes} = RenameNode.call(nodes, 1, "start-here", "Start Here")

    assert [
             %{
               id: 1,
               page_id: "page-id",
               parent_id: nil,
               slug: "start-here",
               title: "Start Here"
             },
             %{id: 2, page_id: nil, parent_id: 1, slug: "notes", title: "Notes"}
           ] = renamed_nodes
  end

  test "returns an error when the node does not exist" do
    assert {:error, "node not found"} = RenameNode.call([], 1, "start-here", "Start Here")
  end
end
