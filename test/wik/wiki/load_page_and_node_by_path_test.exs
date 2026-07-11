defmodule Wik.Wiki.LoadPageAndNodeByPathTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.Membership
  alias Wik.Scope
  alias Wik.Wiki
  alias Wik.Wiki.Page

  test "loads the existing node and linked page" do
    actor = generate(user())
    space = generate(space())
    add_membership(space, actor, :member)
    grant_active_telegram_access(space, actor)
    scope = scope(actor, space)
    {:ok, page} = Page.create(authorize?: false, scope: scope)

    generate(
      page_tree(
        space: space,
        nodes: [
          %{id: 1, page_id: page.id, parent_id: nil, slug: "home", title: "Home"}
        ]
      )
    )

    {node, loaded_page} =
      Wiki.load_page_and_node_by_path("home", scope: scope, load: [:author])

    assert node.slug == "home"
    assert loaded_page.id == page.id
  end

  test "loads an existing node without creating a page for it" do
    actor = generate(user())
    space = generate(space())
    add_membership(space, actor, :member)
    grant_active_telegram_access(space, actor)
    scope = scope(actor, space)

    generate(
      page_tree(
        space: space,
        nodes: [
          %{id: 1, page_id: nil, parent_id: nil, slug: "draft", title: "Draft"}
        ]
      )
    )

    {node, page} = Wiki.load_page_and_node_by_path("draft", scope: scope)

    assert node.slug == "draft"
    assert page == nil
    assert {:ok, []} = Ash.read(Page, scope: scope)
  end

  test "returns nils for a missing path without creating anything" do
    actor = generate(user())
    space = generate(space())
    add_membership(space, actor, :member)
    grant_active_telegram_access(space, actor)
    scope = scope(actor, space)

    {node, page} = Wiki.load_page_and_node_by_path("missing/path", scope: scope)

    assert node == nil
    assert page == nil
    assert {:ok, []} = Ash.read(Page, scope: scope)
  end

  test "ensure_page_and_node_at_path creates a missing page and node for a manager" do
    actor = generate(user())
    space = generate(space())
    add_membership(space, actor, :owner)
    scope = scope(actor, space)

    assert {:ok, node, page} =
             Wiki.ensure_page_and_node_at_path("docs/guide", scope: scope, load: [:author])

    assert node.slug == "guide"
    assert page.id != nil

    {loaded_node, loaded_page} =
      Wiki.load_page_and_node_by_path("docs/guide", scope: scope, load: [:author])

    assert loaded_node.id == node.id
    assert loaded_page.id == page.id
  end

  test "ensure_page_and_node_at_path creates home in a space with a 16-character slug" do
    actor = generate(user())
    space = generate(space(slug: "damn-interesting"))
    add_membership(space, actor, :owner)
    scope = scope(actor, space)

    assert {:ok, node, page} =
             Wiki.ensure_page_and_node_at_path("home", scope: scope, load: [:author])

    assert node.slug == "home"
    assert page.id != nil

    page_tree = Wiki.load_page_tree(scope)

    assert {:ok, loaded_node} = Wik.Wiki.PageTree.get_node_by_path(page_tree.nodes, "home")
    assert loaded_node.page_id == page.id
  end

  test "ensure_page_and_node_at_path creates a page for an existing node without one" do
    actor = generate(user())
    space = generate(space())
    add_membership(space, actor, :owner)
    scope = scope(actor, space)

    generate(
      page_tree(
        space: space,
        nodes: [
          %{id: 1, page_id: nil, parent_id: nil, slug: "draft", title: "Draft"}
        ]
      )
    )

    assert {:ok, node, page} =
             Wiki.ensure_page_and_node_at_path("draft", scope: scope, load: [:author])

    assert node.slug == "draft"
    assert page.id != nil

    {loaded_node, loaded_page} =
      Wiki.load_page_and_node_by_path("draft", scope: scope, load: [:author])

    assert loaded_node.id == node.id
    assert loaded_page.id == page.id
  end

  test "ensure_page_and_node_at_path uses title_path titles for missing nodes" do
    actor = generate(user())
    space = generate(space())
    add_membership(space, actor, :owner)
    scope = scope(actor, space)

    assert {:ok, node, _page} =
             Wiki.ensure_page_and_node_at_path(
               "soups/vegetable-soup",
               scope: scope,
               load: [:author],
               title_path: "Soups/Vegetable soup"
             )

    assert node.slug == "vegetable-soup"
    assert node.title == "Vegetable soup"

    page_tree = Wiki.load_page_tree(scope)

    assert {:ok, soups_node} =
             Wik.Wiki.PageTree.get_node_by_path(page_tree.nodes, "soups")

    assert soups_node.title == "Soups"
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
