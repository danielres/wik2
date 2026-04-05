defmodule Qblog.Wiki.PageTree.DestroyNodeTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Scope
  alias Qblog.Wiki.Page
  alias Qblog.Wiki.PageTree

  test "destroy_node keeps the associated page by default" do
    author = generate(user())
    group = generate(group(author: author))
    scope = %Scope{actor: author, tenant: group}
    {:ok, page} = Page.create(scope: scope)

    page_tree =
      generate(
        page_tree(
          group: group,
          nodes: [
            %{id: 1, page_id: page.id, parent_id: nil, slug: "home", title: "Home"}
          ]
        )
      )

    assert {:ok, page_tree} = PageTree.destroy_node(page_tree, 1, scope: scope)
    assert page_tree.nodes == []
    assert {:ok, %{id: id}} = Page.get_by_id(page.id, authorize?: false, scope: scope)
    assert id == page.id
  end

  test "destroy_node destroys the associated page when destroy_page? is true" do
    author = generate(user())
    group = generate(group(author: author))
    scope = %Scope{actor: author, tenant: group}
    {:ok, page} = Page.create(scope: scope)

    page_tree =
      generate(
        page_tree(
          group: group,
          nodes: [
            %{id: 1, page_id: page.id, parent_id: nil, slug: "home", title: "Home"}
          ]
        )
      )

    assert {:ok, page_tree} =
             PageTree.destroy_node(page_tree, 1, scope: scope, destroy_page?: true)

    assert page_tree.nodes == []
    assert {:error, _error} = Page.get_by_id(page.id, authorize?: false, scope: scope)
  end
end
