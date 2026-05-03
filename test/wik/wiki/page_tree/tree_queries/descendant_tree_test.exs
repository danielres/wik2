defmodule Wik.Wiki.PageTree.TreeQueries.DescendantTreeTest do
  use ExUnit.Case, async: true

  alias Wik.Wiki.PageTree.TreeQueries

  test "root depth 1 returns root nodes" do
    nodes = nodes_fixture()

    assert [
             %{id: 1, children: []},
             %{id: 5, children: []}
           ] = strip(TreeQueries.get_root_descendant_tree(nodes, 1))
  end

  test "node depth 1 returns the source node" do
    nodes = nodes_fixture()

    assert [
             %{id: 1, children: []}
           ] = strip(TreeQueries.get_node_tree(nodes, 1, 1))
  end

  test "node depth 2 returns source node and direct children" do
    nodes = nodes_fixture()

    assert [
             %{
               id: 1,
               children: [
                 %{id: 2, children: []},
                 %{id: 4, children: []}
               ]
             }
           ] = strip(TreeQueries.get_node_tree(nodes, 1, 2))
  end

  test "node depth 3 returns nested descendants" do
    nodes = nodes_fixture()

    assert [
             %{
               id: 1,
               children: [
                 %{id: 2, children: [%{id: 3, children: []}]},
                 %{id: 4, children: []}
               ]
             }
           ] = strip(TreeQueries.get_node_tree(nodes, 1, 3))
  end

  defp nodes_fixture do
    [
      %{id: 1, page_id: nil, parent_id: nil, slug: "docs", title: "Docs"},
      %{id: 2, page_id: nil, parent_id: 1, slug: "guide", title: "Guide"},
      %{id: 3, page_id: nil, parent_id: 2, slug: "intro", title: "Intro"},
      %{id: 4, page_id: nil, parent_id: 1, slug: "faq", title: "FAQ"},
      %{id: 5, page_id: nil, parent_id: nil, slug: "blog", title: "Blog"}
    ]
  end

  defp strip(tree) do
    Enum.map(tree, fn node ->
      %{
        id: node.id,
        children: strip(node.children)
      }
    end)
  end
end
