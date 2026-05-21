defmodule WikWeb.Components.TagTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest, only: [render_component: 2]
  import Wik.TestGenerators

  alias Wik.Accounts.GroupUserRelation
  alias Wik.Scope
  alias Wik.Tags
  alias WikWeb.Components.Tag

  test "breadcrumbs renders one clickable path per parent path" do
    owner = generate(user())
    group = generate(group(author: owner))
    add_membership(group, owner, :owner)
    scope = scope(owner, group)

    {:ok, recipes} = Tags.create_tag("recipes", "Recipes", nil, scope: scope)
    {:ok, soups} = Tags.create_tag("soups", "Soups", nil, scope: scope)
    {:ok, healthy} = Tags.create_tag("healthy-ideas", "Healthy ideas", nil, scope: scope)
    {:ok, stew} = Tags.create_tag("irish-stew", "Irish stew", nil, scope: scope)

    assert {:ok, _edge} = Tags.link_tags(recipes.id, soups.id, scope: scope)
    assert {:ok, _edge} = Tags.link_tags(soups.id, stew.id, scope: scope)
    assert {:ok, _edge} = Tags.link_tags(healthy.id, stew.id, scope: scope)

    html =
      render_component(&Tag.breadcrumbs/1, %{
        render_root?: true,
        render_self?: true,
        scope: scope,
        tag: stew
      })

    assert html =~ ~s(data-testid="tag-breadcrumbs")
    assert html =~ ~s(data-testid="tag-breadcrumbs-path-0")
    assert html =~ ~s(data-testid="tag-breadcrumbs-path-1")
    assert html =~ ~s(href="/#{group.slug}/tags")
    assert html =~ ~s(href="/#{group.slug}/tags/recipes")
    assert html =~ ~s(href="/#{group.slug}/tags/soups")
    assert html =~ ~s(href="/#{group.slug}/tags/healthy-ideas")
    assert html =~ ~s(href="/#{group.slug}/tags/irish-stew")
  end

  test "breadcrumbs keeps a trailing separator when render_self? is false" do
    owner = generate(user())
    group = generate(group(author: owner))
    add_membership(group, owner, :owner)
    scope = scope(owner, group)

    {:ok, recipes} = Tags.create_tag("recipes", "Recipes", nil, scope: scope)
    {:ok, soups} = Tags.create_tag("soups", "Soups", nil, scope: scope)
    {:ok, stew} = Tags.create_tag("irish-stew", "Irish stew", nil, scope: scope)

    assert {:ok, _edge} = Tags.link_tags(recipes.id, soups.id, scope: scope)
    assert {:ok, _edge} = Tags.link_tags(soups.id, stew.id, scope: scope)

    html =
      render_component(&Tag.breadcrumbs/1, %{
        render_root?: true,
        render_self?: false,
        scope: scope,
        tag: stew
      })

    assert html =~ ~s(href="/#{group.slug}/tags")
    assert html =~ ~s(href="/#{group.slug}/tags/recipes")
    assert html =~ ~s(href="/#{group.slug}/tags/soups")
    refute html =~ ~s(href="/#{group.slug}/tags/irish-stew")
    assert html =~ ">"
  end

  defp add_membership(group, user, type) do
    Ash.create!(
      GroupUserRelation,
      %{group_id: group.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
  end

  defp scope(actor, tenant), do: %Scope{actor: actor, tenant: tenant}
end
