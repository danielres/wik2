defmodule Wik.Wiki.PageTree.WikilinksTest do
  use Wik.DataCase, async: true

  alias Wik.Wiki.PageTree
  alias Wik.Wiki.PageTree.Node
  alias Wik.Wiki.PageTree.Wikilinks

  test "converts visible title-path wikilinks to canonical node wikilinks" do
    page_tree = page_tree_fixture()
    title_path_to_node_map = page_tree.nodes |> Wikilinks.title_paths_to_node_id_map()

    assert Wikilinks.title_paths_to_nodes(
             "[[Soups]] and [[Soups/Vegetable Soup]]",
             title_path_to_node_map
           ) == "[[node:1]] and [[node:2]]"
  end

  test "converts canonical node wikilinks back to visible title-path wikilinks" do
    page_tree = page_tree_fixture()

    assert Wikilinks.nodes_to_title_paths(
             "[[node:1]] and [[node:2]]",
             page_tree
           ) == "[[Soups]] and [[Soups/Vegetable Soup]]"
  end

  test "converts visible member wikilinks to canonical membership wikilinks" do
    assert Wikilinks.usernames_to_memberships(
             "[[@alice]] and [[Soups]]",
             %{"alice" => "membership-1"}
           ) == "[[member:membership-1]] and [[Soups]]"
  end

  test "converts canonical membership wikilinks back to visible member wikilinks" do
    assert Wikilinks.memberships_to_usernames(
             "[[member:membership-1]] and [[node:1]]",
             %{"membership-1" => "alice"}
           ) == "[[@alice]] and [[node:1]]"
  end

  test "converts visible tag wikilinks to canonical tag wikilinks" do
    assert Wikilinks.tag_names_to_tags(
             "[[#Dance]] and [[Soups]]",
             %{"Dance" => "tag-1"}
           ) == "[[tag:tag-1]] and [[Soups]]"
  end

  test "converts canonical tag wikilinks back to visible tag wikilinks" do
    assert Wikilinks.tags_to_tag_names(
             "[[tag:tag-1]] and [[node:1]]",
             %{"tag-1" => "Dance"}
           ) == "[[#Dance]] and [[node:1]]"
  end

  test "slugifies title paths for unresolved wikilinks" do
    assert Wikilinks.slug_path_from_title_path("Soups/Vegetable Soup") == "soups/vegetable-soup"
  end

  defp page_tree_fixture do
    %PageTree{
      nodes: [
        %Node{
          id: 1,
          page_id: "11111111-1111-1111-1111-111111111111",
          parent_id: nil,
          slug: "soups",
          title: "Soups"
        },
        %Node{
          id: 2,
          page_id: "22222222-2222-2222-2222-222222222222",
          parent_id: 1,
          slug: "vegetable-soup",
          title: "Vegetable Soup"
        }
      ]
    }
  end
end
