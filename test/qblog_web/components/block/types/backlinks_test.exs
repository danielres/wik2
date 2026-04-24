defmodule QblogWeb.Components.Block.Types.BacklinksTest do
  use QblogWeb.ConnCase, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]
  import Qblog.TestGenerators

  alias Qblog.Accounts.GroupUserRelation
  alias Qblog.Blocks
  alias Qblog.Scope
  alias Qblog.Wiki.Page
  alias QblogWeb.Components.Block.Types.Backlinks

  test "render shows clickable backlink pages" do
    actor = generate(user())
    group = generate(group())
    add_membership(group, actor, :owner)
    scope = %Scope{actor: actor, tenant: group}

    {:ok, target_page} = Page.create(scope: scope)
    {:ok, source_page} = Page.create(scope: scope)

    page_tree =
      generate(
        page_tree(
          group: group,
          nodes: [
            %{id: 1, page_id: target_page.id, parent_id: nil, slug: "target", title: "Target"},
            %{id: 2, page_id: source_page.id, parent_id: nil, slug: "source", title: "Source"}
          ]
        )
      )

    assert {:ok, _block} =
             Blocks.create_user_owned_block_on_page(
               source_page,
               %{type: :markdown, data: %{"text" => "[[node:1]]"}},
               scope: scope
             )

    html =
      render_component(&Backlinks.render/1, %{
        block: %{id: "block-1", data: %{"title" => ""}},
        node: Enum.find(page_tree.nodes, &(&1.id == 1)),
        page_tree: page_tree,
        scope: scope
      })

    document = LazyHTML.from_fragment(html)

    assert document
           |> LazyHTML.query(
             ~s([data-testid="backlinks-list"] a[href="/#{group.name}/wiki/source"])
           )
           |> Enum.any?()
  end

  test "render shows empty state when there are no backlinks" do
    actor = generate(user())
    group = generate(group())
    add_membership(group, actor, :owner)
    scope = %Scope{actor: actor, tenant: group}
    {:ok, target_page} = Page.create(scope: scope)

    page_tree =
      generate(
        page_tree(
          group: group,
          nodes: [
            %{id: 1, page_id: target_page.id, parent_id: nil, slug: "target", title: "Target"}
          ]
        )
      )

    html =
      render_component(&Backlinks.render/1, %{
        block: %{id: "block-1", data: %{"title" => ""}},
        node: Enum.find(page_tree.nodes, &(&1.id == 1)),
        page_tree: page_tree,
        scope: scope
      })

    document = LazyHTML.from_fragment(html)

    assert document |> LazyHTML.query(~s([data-testid="backlinks-empty"])) |> Enum.any?()
  end

  test "render shows placeholder when page context is missing" do
    html =
      render_component(&Backlinks.render/1, %{
        block: %{id: "block-1", data: %{"title" => ""}},
        scope: nil,
        node: nil,
        page_tree: nil
      })

    document = LazyHTML.from_fragment(html)

    assert document
           |> LazyHTML.query(~s([data-testid="backlinks-missing-context"]))
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
end
