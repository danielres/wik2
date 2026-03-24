defmodule Qblog.Wiki.PageTree.TreeQueries.BuildTreeTest do
  use ExUnit.Case, async: true

  alias Qblog.Wiki.PageTree.TreeQueries

  test "builds a tree from flat nodes" do
    nodes = [
      %{id: 1, page_id: nil, parent_id: nil, slug: "home", title: "Home"},
      %{id: 2, page_id: nil, parent_id: 1, slug: "about", title: "About"},
      %{id: 3, page_id: nil, parent_id: 1, slug: "contact", title: "Contact"}
    ]

    assert [
             %{
               id: 1,
               children: [
                 %{id: 2, children: []},
                 %{id: 3, children: []}
               ]
             }
           ] = strip(TreeQueries.build_tree(nodes))
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
