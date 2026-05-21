defmodule Wik.Wiki.PageTree.DestroyNodeTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.Membership
  alias Wik.Scope
  alias Wik.Wiki.Page
  alias Wik.Wiki.PageTree

  test "destroy_node keeps the associated page by default" do
    author = generate(user())
    space = generate(space(author: author))
    add_membership(space, author, :owner)
    scope = %Scope{actor: author, tenant: space}
    {:ok, page} = Page.create(authorize?: false, scope: scope)

    page_tree =
      generate(
        page_tree(
          space: space,
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
    space = generate(space(author: author))
    add_membership(space, author, :owner)
    scope = %Scope{actor: author, tenant: space}
    {:ok, page} = Page.create(authorize?: false, scope: scope)

    page_tree =
      generate(
        page_tree(
          space: space,
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

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
  end
end
