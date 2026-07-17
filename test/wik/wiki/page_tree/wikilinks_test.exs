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

  test "converts visible member subpage wikilinks to canonical membership subpage wikilinks" do
    assert Wikilinks.usernames_to_memberships(
             "[[@alice/test]] and [[Soups]]",
             %{"alice" => "membership-1"}
           ) == "[[member:membership-1/test]] and [[Soups]]"
  end

  test "converts canonical membership wikilinks back to visible member wikilinks" do
    assert Wikilinks.memberships_to_usernames(
             "[[member:membership-1]] and [[node:1]]",
             %{"membership-1" => "alice"}
           ) == "[[@alice]] and [[node:1]]"
  end

  test "converts canonical membership subpage wikilinks back to visible member subpage wikilinks" do
    assert Wikilinks.memberships_to_usernames(
             "[[member:membership-1/test]] and [[node:1]]",
             %{"membership-1" => "alice"}
           ) == "[[@alice/test]] and [[node:1]]"
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

  test "lists member profile subpage paths for existing usernames" do
    page_tree = profile_page_tree_fixture()

    assert Wikilinks.member_profile_paths(page_tree.nodes, ["tom"]) == ["tom/recipes"]
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

  defp profile_page_tree_fixture do
    %PageTree{
      nodes: [
        %Node{
          id: 1,
          parent_id: nil,
          slug: "members",
          title: "Members"
        },
        %Node{
          id: 2,
          page_id: "22222222-2222-2222-2222-222222222222",
          parent_id: 1,
          slug: "tom",
          title: "Tom"
        },
        %Node{
          id: 3,
          page_id: "33333333-3333-3333-3333-333333333333",
          parent_id: 2,
          slug: "recipes",
          title: "Recipes"
        },
        %Node{
          id: 4,
          page_id: "44444444-4444-4444-4444-444444444444",
          parent_id: 1,
          slug: "sara",
          title: "Sara"
        },
        %Node{
          id: 5,
          page_id: "55555555-5555-5555-5555-555555555555",
          parent_id: 4,
          slug: "notes",
          title: "Notes"
        }
      ]
    }
  end
end
