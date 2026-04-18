defmodule QblogWeb.Components.Block.AddBlockMenuButtonTest do
  use QblogWeb.ConnCase, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]
  import Qblog.TestGenerators

  alias Qblog.Accounts.GroupUserRelation
  alias Qblog.Scope
  alias Qblog.Wiki.Page
  alias QblogWeb.Components.Block.AddBlockMenuButton

  test "shows the child pages option when child pages are available" do
    actor = generate(user())
    group = generate(group())
    add_membership(group, actor, :member)
    scope = scope(actor, group)
    {:ok, source_page} = Page.create(authorize?: false, scope: scope)
    {:ok, child_page} = Page.create(authorize?: false, scope: scope)

    generate(
      page_tree(
        group: group,
        nodes: [
          %{id: 1, page_id: source_page.id, parent_id: nil, slug: "members", title: "Members"},
          %{id: 2, page_id: child_page.id, parent_id: 1, slug: "alice", title: "Alice"}
        ]
      )
    )

    html =
      render_component(&AddBlockMenuButton.render/1, %{
        class: "btn",
        id: "special-blocks",
        scope: scope
      })

    assert html =~ "Embed"
    assert html =~ "Linked copy"
    assert html =~ ~s(phx-value-type="linked_copy")
    assert html =~ "Members"
    assert html =~ ~s(phx-value-type="members")
    assert html =~ "Child pages"
    assert html =~ ~s(phx-value-type="child_pages")
  end

  test "hides the child pages option when no source pages are available" do
    actor = generate(user())
    group = generate(group())
    add_membership(group, actor, :member)
    scope = scope(actor, group)
    {:ok, leaf_page} = Page.create(authorize?: false, scope: scope)

    generate(
      page_tree(
        group: group,
        nodes: [
          %{id: 1, page_id: leaf_page.id, parent_id: nil, slug: "faq", title: "FAQ"}
        ]
      )
    )

    html =
      render_component(&AddBlockMenuButton.render/1, %{
        class: "btn",
        id: "special-blocks",
        scope: scope
      })

    assert html =~ "Embed"
    assert html =~ "Linked copy"
    assert html =~ ~s(phx-value-type="linked_copy")
    assert html =~ "Members"
    assert html =~ ~s(phx-value-type="members")
    refute html =~ "Child pages"
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
