defmodule Wik.Wiki.BacklinksTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.Membership
  alias Wik.Blocks
  alias Wik.Scope
  alias Wik.Wiki.Backlinks
  alias Wik.Wiki.Page

  test "lists unique markdown backlinking pages for the current node" do
    actor = generate(user())
    space = generate(space())
    add_membership(space, actor, :owner)
    scope = scope(actor, space)

    {:ok, target_page} = Page.create(scope: scope)
    {:ok, source_page} = Page.create(scope: scope)
    {:ok, other_page} = Page.create(scope: scope)
    {:ok, self_page} = Page.create(scope: scope)

    page_tree =
      generate(
        page_tree(
          space: space,
          nodes: [
            %{id: 1, page_id: target_page.id, parent_id: nil, slug: "target", title: "Target"},
            %{id: 2, page_id: source_page.id, parent_id: nil, slug: "source", title: "Source"},
            %{id: 3, page_id: other_page.id, parent_id: nil, slug: "other", title: "Other"},
            %{id: 4, page_id: self_page.id, parent_id: nil, slug: "self", title: "Self"}
          ]
        )
      )

    assert {:ok, _block} =
             Blocks.create_user_owned_block_on_page(
               source_page,
               %{type: :markdown, data: %{"text" => "[[node:1]]\n\n[[node:1]]"}},
               scope: scope
             )

    assert {:ok, markdown_block} =
             Blocks.create_user_owned_block(
               %{type: :markdown, data: %{"text" => "[[node:1]]"}},
               scope: scope
             )

    assert {:ok, _placement} =
             Blocks.place_block_on_page(markdown_block, other_page, scope: scope)

    assert {:ok, _block} =
             Blocks.create_user_owned_block_on_page(
               self_page,
               %{type: :markdown, data: %{"text" => "[[node:1]]"}},
               scope: scope
             )

    assert {:ok, _block} =
             Blocks.create_user_owned_block_on_page(
               target_page,
               %{type: :markdown, data: %{"text" => "[[node:1]]"}},
               scope: scope
             )

    assert {:ok, _block} =
             Blocks.create_user_owned_block_on_page(
               other_page,
               %{type: :text, data: %{"text" => "[[node:1]]"}},
               scope: scope
             )

    target_node = Enum.find(page_tree.nodes, &(&1.id == 1))

    assert {:ok, backlinks} = Backlinks.list_pages_linking_to_node(scope, target_node, page_tree)

    assert backlinks == [
             %{node_id: 3, page_id: other_page.id, path: "other", title: "Other"},
             %{node_id: 4, page_id: self_page.id, path: "self", title: "Self"},
             %{node_id: 2, page_id: source_page.id, path: "source", title: "Source"}
           ]
  end

  test "ignores linking pages that are missing from the page tree" do
    actor = generate(user())
    space = generate(space())
    add_membership(space, actor, :owner)
    scope = scope(actor, space)

    {:ok, target_page} = Page.create(scope: scope)
    {:ok, source_page} = Page.create(scope: scope)

    page_tree =
      generate(
        page_tree(
          space: space,
          nodes: [
            %{id: 1, page_id: target_page.id, parent_id: nil, slug: "target", title: "Target"}
          ]
        )
      )

    assert {:ok, _block} =
             Blocks.create_user_owned_block_on_page(
               source_page,
               %{type: :markdown, data: %{"text" => "[[node:1]]"}},
               scope: scope
             )

    target_node = Enum.find(page_tree.nodes, &(&1.id == 1))

    assert {:ok, []} = Backlinks.list_pages_linking_to_node(scope, target_node, page_tree)
  end

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
  end

  defp scope(actor, tenant) do
    %Scope{actor: actor, tenant: tenant}
  end
end
