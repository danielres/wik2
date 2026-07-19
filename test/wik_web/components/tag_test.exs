defmodule WikWeb.Components.TagTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest, only: [render_component: 2]
  import Wik.TestGenerators

  alias Wik.Accounts.Membership
  alias Wik.Scope
  alias Wik.Tags
  alias WikWeb.Components.Tag

  test "breadcrumbs renders one clickable path per parent path" do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    scope = scope(owner, space)

    {:ok, recipes} = Tags.create_tag("recipes", "Recipes", scope: scope)
    {:ok, soups} = Tags.create_tag("soups", "Soups", scope: scope)
    {:ok, healthy} = Tags.create_tag("healthy-ideas", "Healthy ideas", scope: scope)
    {:ok, stew} = Tags.create_tag("irish-stew", "Irish stew", scope: scope)

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
    assert html =~ ~s(href="/#{space.slug}/topics")
    assert html =~ ~s(href="/#{space.slug}/topics/recipes")
    assert html =~ ~s(href="/#{space.slug}/topics/soups")
    assert html =~ ~s(href="/#{space.slug}/topics/healthy-ideas")
    assert html =~ ~s(href="/#{space.slug}/topics/irish-stew")
  end

  test "breadcrumbs keeps a trailing separator when render_self? is false" do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    scope = scope(owner, space)

    {:ok, recipes} = Tags.create_tag("recipes", "Recipes", scope: scope)
    {:ok, soups} = Tags.create_tag("soups", "Soups", scope: scope)
    {:ok, stew} = Tags.create_tag("irish-stew", "Irish stew", scope: scope)

    assert {:ok, _edge} = Tags.link_tags(recipes.id, soups.id, scope: scope)
    assert {:ok, _edge} = Tags.link_tags(soups.id, stew.id, scope: scope)

    html =
      render_component(&Tag.breadcrumbs/1, %{
        render_root?: true,
        render_self?: false,
        scope: scope,
        tag: stew
      })

    assert html =~ ~s(href="/#{space.slug}/topics")
    assert html =~ ~s(href="/#{space.slug}/topics/recipes")
    assert html =~ ~s(href="/#{space.slug}/topics/soups")
    refute html =~ ~s(href="/#{space.slug}/topics/irish-stew")
    assert html =~ ">"
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
