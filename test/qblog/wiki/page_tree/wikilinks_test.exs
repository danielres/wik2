defmodule Qblog.Wiki.PageTree.WikilinksTest do
  use Qblog.DataCase, async: true

  alias Qblog.Wiki.PageTree
  alias Qblog.Wiki.PageTree.Node
  alias Qblog.Wiki.PageTree.Wikilinks

  test "converts visible wikilinks to canonical node wikilinks" do
    page_tree = page_tree_fixture()
    path_to_node_map = page_tree.nodes |> Wikilinks.nodes_to_id_map()

    assert Wikilinks.paths_to_nodes(
             "[[recipes]] and [[recipes/soup]]",
             path_to_node_map
           ) == "[[node:1]] and [[node:2]]"
  end

  test "converts canonical node wikilinks back to visible wikilinks" do
    page_tree = page_tree_fixture()

    assert Wikilinks.nodes_to_paths(
             "[[node:1]] and [[node:2]]",
             page_tree
           ) == "[[recipes]] and [[recipes/soup]]"
  end

  defp page_tree_fixture do
    %PageTree{
      nodes: [
        %Node{
          id: 1,
          page_id: "11111111-1111-1111-1111-111111111111",
          parent_id: nil,
          slug: "recipes",
          title: "Recipes"
        },
        %Node{
          id: 2,
          page_id: "22222222-2222-2222-2222-222222222222",
          parent_id: 1,
          slug: "soup",
          title: "Soup"
        }
      ]
    }
  end
end
