defmodule QblogWeb.Components.Block.Types.PagesTest do
  use QblogWeb.ConnCase, async: true

  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]
  import Qblog.TestGenerators

  alias Qblog.Accounts.GroupUserRelation
  alias Qblog.Scope
  alias Qblog.Wiki.Page
  alias QblogWeb.Components.Block.Types.Pages

  test "form_fields renders root, source nodes, and depth" do
    actor = generate(user())
    group = generate(group())
    add_membership(group, actor, :member)
    grant_active_telegram_access(group, actor)
    scope = scope(actor, group)
    {:ok, docs_page} = Page.create(authorize?: false, scope: scope)
    {:ok, guide_page} = Page.create(authorize?: false, scope: scope)

    generate(
      page_tree(
        group: group,
        nodes: [
          %{id: 1, page_id: docs_page.id, parent_id: nil, slug: "docs", title: "Docs"},
          %{id: 2, page_id: guide_page.id, parent_id: 1, slug: "guide", title: "Guide"}
        ]
      )
    )

    html =
      render_component(&Pages.form_fields/1, %{
        block: %{id: "block-1", data: %{"depth" => 1, "source_node" => "root", "title" => ""}},
        form: to_form(%{"depth" => 1, "source_node" => "root"}, as: :block),
        scope: scope
      })

    assert html =~ ~s(name="block[source_node]")
    assert html =~ ~s(<option selected value="root">Root</option>)
    assert html =~ ~s(<option value="1">Docs</option>)
    assert html =~ ~s(name="block[depth]")
    assert html =~ ~s(type="number")
  end

  test "render links source node and descendants by wiki path and respects depth" do
    actor = generate(user())
    group = generate(group())
    add_membership(group, actor, :member)
    grant_active_telegram_access(group, actor)
    scope = scope(actor, group)
    {:ok, docs_page} = Page.create(authorize?: false, scope: scope)
    {:ok, guide_page} = Page.create(authorize?: false, scope: scope)
    {:ok, intro_page} = Page.create(authorize?: false, scope: scope)

    generate(
      page_tree(
        group: group,
        nodes: [
          %{id: 1, page_id: docs_page.id, parent_id: nil, slug: "docs", title: "Docs"},
          %{id: 2, page_id: guide_page.id, parent_id: 1, slug: "guide", title: "Guide"},
          %{id: 3, page_id: intro_page.id, parent_id: 2, slug: "intro", title: "Intro"}
        ]
      )
    )

    html =
      render_component(&Pages.render/1, %{
        block: %{data: %{"depth" => 2, "source_node" => 1, "title" => ""}, type: :pages},
        scope: scope
      })

    assert html =~ ~s(href="/#{group.name}/wiki/docs")
    assert html =~ ~s(href="/#{group.name}/wiki/docs/guide")
    refute html =~ ~s(href="/#{group.name}/wiki/docs/guide/intro")
  end

  test "render shows a missing-node message when the configured source node no longer exists" do
    actor = generate(user())
    group = generate(group())
    add_membership(group, actor, :member)
    grant_active_telegram_access(group, actor)
    scope = scope(actor, group)

    html =
      render_component(&Pages.render/1, %{
        block: %{data: %{"depth" => 1, "source_node" => 99, "title" => ""}, type: :pages},
        scope: scope
      })

    assert html
           |> LazyHTML.from_fragment()
           |> LazyHTML.query(testid("pages-source-missing"))
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
