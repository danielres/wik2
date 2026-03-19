defmodule Qblog.Wiki.PageTree.TreeOps.AddChildTest do
  use ExUnit.Case, async: true

  alias Qblog.Wiki.PageTree.TreeOps.AddChild

  test "adds a root node when parent_node_id is nil" do
    nodes = []

    assert {:ok, new_nodes} = AddChild.call(nodes, nil)

    assert [
             %{
               id: 1,
               page_id: nil,
               parent_id: nil
             }
           ] = new_nodes
  end

  test "adds a child under an existing parent node" do
    nodes = [
      %{
        :id => 1,
        :page_id => nil,
        :parent_id => nil
      }
    ]

    assert {:ok, new_nodes} = AddChild.call(nodes, 1)

    assert [
             %{
               :id => 1,
               :page_id => nil,
               :parent_id => nil
             },
             %{
               :id => 2,
               :page_id => nil,
               :parent_id => 1
             }
           ] = new_nodes
  end

  test "adds a second root node when parent_node_id is nil" do
    nodes = [
      %{
        :id => 1,
        :page_id => nil,
        :parent_id => nil
      }
    ]

    assert {:ok, new_nodes} = AddChild.call(nodes, nil)

    assert [
             %{
               :id => 1,
               :page_id => nil,
               :parent_id => nil
             },
             %{
               :id => 2,
               :page_id => nil,
               :parent_id => nil
             }
           ] = new_nodes
  end

  test "returns an error when parent node does not exist" do
    nodes = []

    assert {:error, "parent node not found"} = AddChild.call(nodes, 999)
  end
end
