defmodule Wik.Tags.GraphQueriesTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.Membership
  alias Wik.Scope
  alias Wik.Tags

  test "roots, parents, children, ancestors, descendants, repeated subtrees, and sibling ordering are projected correctly" do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    scope = scope(owner, space)

    {:ok, alpha} = Tags.create_tag("alpha", "Alpha", scope: scope)
    {:ok, beta} = Tags.create_tag("beta", "Beta", scope: scope)
    {:ok, zed} = Tags.create_tag("zed", "Zed", scope: scope)
    {:ok, shared} = Tags.create_tag("shared", "Shared", scope: scope)
    {:ok, grandchild} = Tags.create_tag("grandchild", "Grandchild", scope: scope)

    assert {:ok, _} = Tags.link_tags(alpha.id, zed.id, scope: scope)
    assert {:ok, _} = Tags.link_tags(alpha.id, shared.id, scope: scope)
    assert {:ok, _} = Tags.link_tags(beta.id, shared.id, scope: scope)
    assert {:ok, _} = Tags.link_tags(shared.id, grandchild.id, scope: scope)

    graph = Tags.load_tag_graph(scope)

    assert Enum.map(graph.root_tags, & &1.name) == ["Alpha", "Beta"]

    assert Enum.map(Tags.list_tag_children(alpha, scope: scope) |> elem(1), & &1.name) == [
             "Shared",
             "Zed"
           ]

    assert Enum.map(Tags.list_tag_parents(shared, scope: scope) |> elem(1), & &1.name) == [
             "Alpha",
             "Beta"
           ]

    assert Enum.map(Tags.list_tag_ancestors(grandchild, scope: scope) |> elem(1), & &1.name) == [
             "Shared",
             "Alpha",
             "Beta"
           ]

    assert Enum.map(Tags.list_tag_descendants(alpha, scope: scope) |> elem(1), & &1.name) == [
             "Shared",
             "Zed",
             "Grandchild"
           ]

    assert [%{children: alpha_children}, %{children: beta_children}] = graph.root_tree
    assert Enum.any?(alpha_children, &(&1.tag.id == shared.id))
    assert Enum.any?(beta_children, &(&1.tag.id == shared.id))
  end

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
  end

  defp scope(actor, tenant), do: %Scope{actor: actor, tenant: tenant}
end
