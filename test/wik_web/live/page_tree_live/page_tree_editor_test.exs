defmodule WikWeb.PageTreeLive.PageTreeEditorTest do
  use WikWeb.ConnCase, async: false

  import Wik.TestGenerators
  import Phoenix.LiveViewTest

  alias Wik.Accounts.GroupUserRelation
  alias Wik.Wiki.PageTree
  alias WikWeb.PageTreeEditorTestLive

  test "add child flow resets on cancel and persists a valid submission", %{conn: conn} do
    group = generate(group())
    superadmin = generate(user(role: :superadmin))
    generate(page_tree(group: group, nodes: base_nodes()))
    {:ok, view, _html} = mount_editor(conn, group.name, superadmin.id)

    render_click(element(view, testid("page-tree-editor-node-2-add-child")))

    assert has_element?(view, testid("add-child-dialog"))
    assert has_element?(view, testid("add-child-modal"))
    assert has_element?(view, testid("add-child-parent-slug"))

    render_change(
      form(view, testid("add-child-form"),
        form: %{"parent_id" => "2", "slug" => "draft-node", "title" => "Draft Node"}
      )
    )

    assert has_element?(view, testid("add-child-auto-slug-draft-node"))

    render_click(element(view, testid("add-child-cancel")))

    refute has_element?(view, testid("add-child-modal"))

    render_click(element(view, testid("page-tree-editor-node-2-add-child")))

    assert has_element?(view, testid("add-child-auto-slug-empty"))
    refute has_element?(view, testid("add-child-auto-slug-draft-node"))

    render_submit(
      form(view, testid("add-child-form"),
        form: %{"parent_id" => "2", "slug" => "faq", "title" => "Faq"}
      )
    )

    assert has_element?(view, testid("add-child-error-nodes"))

    render_submit(
      form(view, testid("add-child-form"),
        form: %{"parent_id" => "2", "slug" => "guide", "title" => "Guide"}
      )
    )

    refute has_element?(view, testid("add-child-modal"))
    assert has_element?(view, testid("page-tree-node-5"))

    assert Enum.any?(
             page_tree_for(group.name, superadmin.id).nodes,
             &(&1.parent_id == 2 and &1.slug == "guide")
           )
  end

  test "move node flow can be canceled and persists the selected parent", %{conn: conn} do
    group = generate(group())
    superadmin = generate(user(role: :superadmin))
    generate(page_tree(group: group, nodes: base_nodes()))
    {:ok, view, _html} = mount_editor(conn, group.name, superadmin.id)

    render_click(element(view, testid("page-tree-editor-node-3-move")))

    assert has_element?(view, testid("move-node-dialog"))
    assert has_element?(view, testid("move-node-modal"))
    assert has_element?(view, testid("move-node-current-node"))
    assert has_element?(view, testid("move-node-to-top"))

    render_click(element(view, testid("move-node-cancel")))

    refute has_element?(view, testid("move-node-modal"))

    render_click(element(view, testid("page-tree-editor-node-3-move")))

    render_click(element(view, testid("move-node-to-parent-1")))

    refute has_element?(view, testid("move-node-modal"))

    assert Enum.any?(
             page_tree_for(group.name, superadmin.id).nodes,
             &(&1.id == 3 and &1.parent_id == 1)
           )
  end

  test "move button stays visible when top level is the only valid destination", %{conn: conn} do
    group = generate(group())
    superadmin = generate(user(role: :superadmin))

    generate(
      page_tree(
        group: group,
        nodes: [
          %{id: 1, page_id: nil, parent_id: nil, slug: "home", title: "Home"},
          %{id: 2, page_id: nil, parent_id: 1, slug: "docs", title: "Docs"}
        ]
      )
    )

    {:ok, view, _html} = mount_editor(conn, group.name, superadmin.id)

    assert has_element?(view, testid("page-tree-editor-node-2-move"))

    render_click(element(view, testid("page-tree-editor-node-2-move")))

    assert has_element?(view, testid("move-node-to-top"))
  end

  test "remove node deletes a leaf node from the rendered tree and persisted state", %{conn: conn} do
    group = generate(group())
    superadmin = generate(user(role: :superadmin))
    generate(page_tree(group: group, nodes: base_nodes()))
    {:ok, view, _html} = mount_editor(conn, group.name, superadmin.id)

    assert has_element?(view, testid("page-tree-node-3"))

    render_click(element(view, testid("page-tree-editor-node-3-remove")))

    refute has_element?(view, testid("page-tree-node-3"))
    refute Enum.any?(page_tree_for(group.name, superadmin.id).nodes, &(&1.id == 3))
  end

  test "read-only mode hides all action buttons", %{conn: conn} do
    group = generate(group())
    member = generate(user())
    add_membership(group, member, :member)
    grant_active_telegram_access(group, member)
    generate(page_tree(group: group, nodes: base_nodes()))
    {:ok, view, _html} = mount_editor(conn, group.name, member.id, editable?: false)

    refute has_element?(view, testid("page-tree-editor-add-root"))
    refute has_element?(view, testid("page-tree-editor-node-2-add-child"))
    refute has_element?(view, testid("page-tree-editor-node-2-move"))
    refute has_element?(view, testid("page-tree-editor-node-3-remove"))
  end

  defp mount_editor(conn, tenant, actor_id, extra_session \\ %{}) do
    extra_session =
      extra_session
      |> Map.new()
      |> Map.new(fn {key, value} -> {to_string(key), value} end)

    session = Map.merge(%{"actor_id" => actor_id, "tenant" => tenant}, extra_session)
    live_isolated(conn, PageTreeEditorTestLive, session: session)
  end

  defp page_tree_for(tenant, actor_id) do
    superadmin =
      Ash.get!(Wik.Accounts.User, actor_id, authorize?: false, domain: Wik.Accounts)

    {:ok, page_tree} = PageTree.ensure(scope: %{actor: superadmin, tenant: tenant})
    page_tree
  end

  defp add_membership(group, user, type) do
    {:ok, membership} =
      Ash.create(
        GroupUserRelation,
        %{group_id: group.id, type: type, user_id: user.id},
        authorize?: false,
        domain: Wik.Accounts
      )

    membership
  end

  defp base_nodes do
    [
      %{id: 1, page_id: nil, parent_id: nil, slug: "home", title: "Home"},
      %{id: 2, page_id: nil, parent_id: nil, slug: "docs", title: "Docs"},
      %{id: 3, page_id: nil, parent_id: 2, slug: "faq", title: "Faq"},
      %{id: 4, page_id: nil, parent_id: nil, slug: "blog", title: "Blog"}
    ]
  end
end
