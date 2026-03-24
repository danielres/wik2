defmodule Qblog.Wiki.PageTree.TreeOps.AddChildTest do
  use ExUnit.Case, async: true

  alias Qblog.Wiki.PageTree.TreeOps.AddChild

  test "adds a root node when parent_node_id is nil" do
    nodes = []

    assert {:ok, new_nodes} = AddChild.call(nodes, "home", "Home", nil)

    assert [
             %{
               id: 1,
               page_id: nil,
               parent_id: nil,
               slug: "home",
               title: "Home"
             }
           ] = new_nodes
  end

  test "adds a child under an existing parent node" do
    nodes = [
      %{
        :id => 1,
        :page_id => nil,
        :parent_id => nil,
        :slug => "home",
        :title => "Home"
      }
    ]

    assert {:ok, new_nodes} = AddChild.call(nodes, "about", "About", 1)

    assert [
             %{
               :id => 1,
               :page_id => nil,
               :parent_id => nil,
               :slug => "home",
               :title => "Home"
             },
             %{
               :id => 2,
               :page_id => nil,
               :parent_id => 1,
               :slug => "about",
               :title => "About"
             }
           ] = new_nodes
  end

  test "adds a second root node when parent_node_id is nil" do
    nodes = [
      %{
        :id => 1,
        :page_id => nil,
        :parent_id => nil,
        :slug => "home",
        :title => "Home"
      }
    ]

    assert {:ok, new_nodes} = AddChild.call(nodes, "about", "About", nil)

    assert [
             %{
               :id => 1,
               :page_id => nil,
               :parent_id => nil,
               :slug => "home",
               :title => "Home"
             },
             %{
               :id => 2,
               :page_id => nil,
               :parent_id => nil,
               :slug => "about",
               :title => "About"
             }
           ] = new_nodes
  end

  test "returns an error when parent node does not exist" do
    nodes = []

    assert {:error, "parent node not found"} = AddChild.call(nodes, "about", "About", 999)
  end
end
