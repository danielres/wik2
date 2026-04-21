defmodule Qblog.Wiki.LoadPageAndNodeByPathTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Accounts.GroupUserRelation
  alias Qblog.Scope
  alias Qblog.Wiki
  alias Qblog.Wiki.Page

  test "loads the existing node and linked page" do
    actor = generate(user())
    group = generate(group())
    add_membership(group, actor, :member)
    grant_active_telegram_access(group, actor)
    scope = scope(actor, group)
    {:ok, page} = Page.create(authorize?: false, scope: scope)

    generate(
      page_tree(
        group: group,
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
    group = generate(group())
    add_membership(group, actor, :member)
    grant_active_telegram_access(group, actor)
    scope = scope(actor, group)

    generate(
      page_tree(
        group: group,
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
    group = generate(group())
    add_membership(group, actor, :member)
    grant_active_telegram_access(group, actor)
    scope = scope(actor, group)

    {node, page} = Wiki.load_page_and_node_by_path("missing/path", scope: scope)

    assert node == nil
    assert page == nil
    assert {:ok, []} = Ash.read(Page, scope: scope)
  end

  test "ensure_page_and_node_at_path creates a missing page and node for a manager" do
    actor = generate(user())
    group = generate(group())
    add_membership(group, actor, :owner)
    scope = scope(actor, group)

    assert {:ok, node, page} =
             Wiki.ensure_page_and_node_at_path("docs/guide", scope: scope, load: [:author])

    assert node.slug == "guide"
    assert page.id != nil

    {loaded_node, loaded_page} =
      Wiki.load_page_and_node_by_path("docs/guide", scope: scope, load: [:author])

    assert loaded_node.id == node.id
    assert loaded_page.id == page.id
  end

  test "ensure_page_and_node_at_path creates a page for an existing node without one" do
    actor = generate(user())
    group = generate(group())
    add_membership(group, actor, :owner)
    scope = scope(actor, group)

    generate(
      page_tree(
        group: group,
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

  defp add_membership(group, user, type) do
    Ash.create!(
      GroupUserRelation,
      %{group_id: group.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Qblog.Accounts
    )
  end

  defp scope(actor, tenant) do
    %Scope{actor: actor, tenant: tenant}
  end
end
