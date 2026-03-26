defmodule QblogWeb.PageTreeLive.PageTreeEditorTest do
  use QblogWeb.ConnCase, async: false

  import Qblog.TestGenerators
  import Phoenix.LiveViewTest

  alias Qblog.Wiki
  alias QblogWeb.PageTreeEditorTestLive

  test "add child flow resets on cancel and persists a valid submission", %{conn: conn} do
    group = generate(group())
    generate(page_tree(group: group, nodes: base_nodes()))
    {:ok, view, _html} = mount_editor(conn, group.name)

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

    assert Enum.any?(page_tree_for(group.name).nodes, &(&1.parent_id == 2 and &1.slug == "guide"))
  end

  test "move node flow can be canceled and persists the selected parent", %{conn: conn} do
    group = generate(group())
    generate(page_tree(group: group, nodes: base_nodes()))
    {:ok, view, _html} = mount_editor(conn, group.name)

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

    assert Enum.any?(page_tree_for(group.name).nodes, &(&1.id == 3 and &1.parent_id == 1))
  end

  test "remove node deletes a leaf node from the rendered tree and persisted state", %{conn: conn} do
    group = generate(group())
    generate(page_tree(group: group, nodes: base_nodes()))
    {:ok, view, _html} = mount_editor(conn, group.name)

    assert has_element?(view, testid("page-tree-node-3"))

    render_click(element(view, testid("page-tree-editor-node-3-remove")))

    refute has_element?(view, testid("page-tree-node-3"))
    refute Enum.any?(page_tree_for(group.name).nodes, &(&1.id == 3))
  end

  defp testid(value), do: ~s([data-testid="#{value}"])

  defp mount_editor(conn, tenant) do
    live_isolated(conn, PageTreeEditorTestLive, session: %{"tenant" => tenant})
  end

  defp page_tree_for(tenant) do
    {:ok, page_tree} = Wiki.get_page_tree(scope: %{tenant: tenant})
    page_tree
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
