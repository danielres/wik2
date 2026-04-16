defmodule QblogWeb.Components.Block.Types.ChildPagesTest do
  use QblogWeb.ConnCase, async: true

  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]
  import Qblog.TestGenerators

  alias Qblog.Accounts.GroupUserRelation
  alias Qblog.Scope
  alias Qblog.Wiki
  alias Qblog.Wiki.Page
  alias QblogWeb.Components.Block.Types.ChildPages

  test "form_fields renders selectable source pages and keeps the selected source" do
    actor = generate(user())
    group = generate(group())
    add_membership(group, actor, :member)
    scope = scope(actor, group)
    {:ok, source_page} = Page.create(authorize?: false, scope: scope)
    {:ok, child_page} = Page.create(authorize?: false, scope: scope)
    {:ok, other_source_page} = Page.create(authorize?: false, scope: scope)
    {:ok, other_child_page} = Page.create(authorize?: false, scope: scope)

    generate(
      page_tree(
        group: group,
        nodes: [
          %{id: 1, page_id: source_page.id, parent_id: nil, slug: "docs", title: "Docs"},
          %{id: 2, page_id: child_page.id, parent_id: 1, slug: "guide", title: "Guide"},
          %{
            id: 3,
            page_id: other_source_page.id,
            parent_id: 1,
            slug: "guides",
            title: "Guides"
          },
          %{id: 4, page_id: other_child_page.id, parent_id: 3, slug: "intro", title: "Intro"}
        ]
      )
    )

    html =
      render_component(&ChildPages.form_fields/1, %{
        node: %{title: "Home"},
        scope: scope,
        block: %{id: "block-1", data: %{"node_id" => 1, "source" => "node"}},
        form: to_form(%{"source_page" => "1"}, as: :block)
      })

    assert html =~ ~s(name="block[source_page]")
    assert html =~ ~s(id="edit-block-source-page-block-1")
    assert html =~ ~s(<option selected value="1">Docs</option>)
    assert html =~ ~s(<option value="3">Docs / Guides</option>)
  end

  test "form_fields keeps a current-page source available while editing" do
    html =
      render_component(&ChildPages.form_fields/1, %{
        node: %{title: "Home"},
        scope: %Scope{actor: nil, tenant: nil},
        block: %{id: "block-2", data: %{"source" => "current_page"}},
        form: to_form(%{"source_page" => "current_page"}, as: :block)
      })

    assert html =~ ~s|<option selected value="current_page">Home (current page)</option>|
  end

  test "render shows the selected parent page title as a clickable heading" do
    actor = generate(user())
    group = generate(group())
    add_membership(group, actor, :member)
    scope = scope(actor, group)
    {:ok, home_page} = Page.create(authorize?: false, scope: scope)
    {:ok, members_page} = Page.create(authorize?: false, scope: scope)
    {:ok, alice_page} = Page.create(authorize?: false, scope: scope)
    {:ok, bob_page} = Page.create(authorize?: false, scope: scope)

    generate(
      page_tree(
        group: group,
        nodes: [
          %{id: 1, page_id: home_page.id, parent_id: nil, slug: "home", title: "Home"},
          %{id: 2, page_id: members_page.id, parent_id: nil, slug: "members", title: "Members"},
          %{id: 3, page_id: alice_page.id, parent_id: 2, slug: "alice", title: "Alice"},
          %{id: 4, page_id: bob_page.id, parent_id: 2, slug: "bob", title: "Bob"}
        ]
      )
    )

    {current_node, _page} = Wiki.load_page_and_node_by_path("home", scope: scope)

    html =
      render_component(&ChildPages.render/1, %{
        block: %{data: %{"node_id" => 2, "source" => "node"}, type: :child_pages},
        node: current_node,
        path: "home",
        scope: scope
      })

    assert html =~ ~s(href="/#{group.name}/wiki/members")
    assert html =~ ~r|>\s*Members\s*</a>|
    assert html =~ ~s(href="/#{group.name}/wiki/members/alice")
    assert html =~ ~s(href="/#{group.name}/wiki/members/bob")
  end

  test "render shows a missing-node message when the configured source node no longer exists" do
    actor = generate(user())
    group = generate(group())
    add_membership(group, actor, :member)
    scope = scope(actor, group)
    {:ok, home_page} = Page.create(authorize?: false, scope: scope)

    generate(
      page_tree(
        group: group,
        nodes: [
          %{id: 1, page_id: home_page.id, parent_id: nil, slug: "home", title: "Home"}
        ]
      )
    )

    {current_node, _page} = Wiki.load_page_and_node_by_path("home", scope: scope)

    html =
      render_component(&ChildPages.render/1, %{
        block: %{data: %{"node_id" => 99, "source" => "node"}, type: :child_pages},
        node: current_node,
        path: "home",
        scope: scope
      })

    assert html
           |> LazyHTML.from_fragment()
           |> LazyHTML.filter(testid("child-pages-source-missing"))
           |> Enum.any?()
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
