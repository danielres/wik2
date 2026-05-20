defmodule WikWeb.Components.Block.Types.MarkdownTest do
  use WikWeb.ConnCase, async: true

  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]
  import Wik.TestGenerators

  alias Wik.Scope
  alias Wik.Accounts.GroupUserRelation
  alias WikWeb.Components.Block.Types.Markdown
  alias Wik.Wiki.PageTree
  alias Wik.Wiki.PageTree.Node

  test "render converts markdown to html" do
    html =
      render_component(&Markdown.render/1, %{
        block: %{id: "block-1", data: %{"text" => "## Title\n\n- One\n- Two"}},
        page_tree: %PageTree{nodes: []}
      })

    document = LazyHTML.from_fragment(html)

    assert document |> LazyHTML.query("h2") |> Enum.any?()
    assert document |> LazyHTML.query("ul li") |> Enum.count() == 2
  end

  test "render converts canonical wikilinks to wiki page links" do
    page_tree = page_tree_fixture()
    scope = %Scope{tenant: %{name: "Cool Stuff", slug: "cool-stuff"}}

    html =
      render_component(&Markdown.render/1, %{
        block: %{id: "block-1", data: %{"text" => "[[node:1]] and [[node:2]]"}},
        page_tree: page_tree,
        scope: scope
      })

    document = LazyHTML.from_fragment(html)

    assert document
           |> LazyHTML.query(~s(a[href="/#{scope.tenant.slug}/wiki/soups"]))
           |> Enum.any?()

    assert document
           |> LazyHTML.query(~s(a[href="/#{scope.tenant.slug}/wiki/soups/vegetable-soup"]))
           |> Enum.any?()

    assert html =~ ">Soups<"
    assert html =~ ">Soups/Vegetable Soup<"
  end

  test "render converts canonical member wikilinks to member profile links" do
    group = generate(group())
    user = generate(user())
    membership = add_membership(group, user, "alice")
    scope = %Scope{tenant: %{id: group.id, name: group.name, slug: group.slug}}

    html =
      render_component(&Markdown.render/1, %{
        block: %{id: "block-1", data: %{"text" => "[[member:#{membership.id}]]"}},
        page_tree: page_tree_fixture(group.id),
        scope: scope
      })

    document = LazyHTML.from_fragment(html)

    assert document
           |> LazyHTML.query(
             ~s(a[href="/#{scope.tenant.slug}/wiki/members/alice"][data-phx-link="patch"][data-phx-link-state="push"])
           )
           |> Enum.any?()

    assert html =~ ">@alice<"
  end

  test "render converts canonical tag wikilinks to tag links" do
    owner = generate(user())
    group = generate(group(author: owner))
    add_owner_membership(group, owner)

    {:ok, tag} =
      Wik.Tags.create_tag("dance", "Dance", nil, scope: %Scope{actor: owner, tenant: group})

    scope = %Scope{tenant: %{id: group.id, name: group.name, slug: group.slug}}

    html =
      render_component(&Markdown.render/1, %{
        block: %{id: "block-1", data: %{"text" => "[[tag:#{tag.id}]]"}},
        page_tree: page_tree_fixture(group.id),
        scope: scope
      })

    document = LazyHTML.from_fragment(html)

    assert document
           |> LazyHTML.query(
             ~s(a[href="/#{scope.tenant.slug}/tags/dance"][data-phx-link="patch"][data-phx-link-state="push"])
           )
           |> Enum.any?()

    assert html =~ ">#Dance<"
  end

  test "render patches canonical wikilinks through the current LiveView" do
    page_tree = page_tree_fixture()
    scope = %Scope{tenant: %{name: "Cool Stuff", slug: "cool-stuff"}}

    html =
      render_component(&Markdown.render/1, %{
        block: %{id: "block-1", data: %{"text" => "[[node:1]]"}},
        page_tree: page_tree,
        scope: scope
      })

    document = LazyHTML.from_fragment(html)

    assert document
           |> LazyHTML.query(
             ~s(a[href="/#{scope.tenant.slug}/wiki/soups"][data-phx-link="patch"][data-phx-link-state="push"])
           )
           |> Enum.any?()
  end

  test "render opens external links in a new tab" do
    html =
      render_component(&Markdown.render/1, %{
        block: %{id: "block-1", data: %{"text" => "[Phoenix](https://phoenixframework.org)"}},
        page_tree: %PageTree{nodes: []}
      })

    document = LazyHTML.from_fragment(html)

    assert document
           |> LazyHTML.query(
             ~s(a[href="https://phoenixframework.org"][target="_blank"][rel="noopener noreferrer"])
           )
           |> Enum.any?()
  end

  test "render does not open internal wiki links in a new tab" do
    page_tree = page_tree_fixture()
    scope = %Scope{tenant: %{name: "Cool Stuff", slug: "cool-stuff"}}

    html =
      render_component(&Markdown.render/1, %{
        block: %{id: "block-1", data: %{"text" => "[[node:1]]"}},
        page_tree: page_tree,
        scope: scope
      })

    document = LazyHTML.from_fragment(html)

    assert document
           |> LazyHTML.query(~s(a[href="/#{scope.tenant.slug}/wiki/soups"]))
           |> Enum.any?()

    refute document
           |> LazyHTML.query(~s(a[href="/#{scope.tenant.slug}/wiki/soups"][target="_blank"]))
           |> Enum.any?()
  end

  test "render unresolved wikilinks as missing-page links using title labels and slug hrefs" do
    scope = %Scope{tenant: %{name: "Cool Stuff", slug: "cool-stuff"}}

    html =
      render_component(&Markdown.render/1, %{
        block: %{id: "block-1", data: %{"text" => "[[Soups/Vegetable Soup]]"}},
        page_tree: %PageTree{nodes: []},
        scope: scope
      })

    document = LazyHTML.from_fragment(html)

    assert document
           |> LazyHTML.query(
             ~s(a[href="/#{scope.tenant.slug}/wiki/soups/vegetable-soup?title_path=Soups%2FVegetable+Soup"][data-wikilink-status="missing"])
           )
           |> Enum.any?()

    assert html =~ ">Soups/Vegetable Soup<"
  end

  test "render leaves unresolved visible tag wikilinks as text" do
    scope = %Scope{tenant: %{name: "Cool Stuff", slug: "cool-stuff"}}

    html =
      render_component(&Markdown.render/1, %{
        block: %{id: "block-1", data: %{"text" => "[[#Unknown Tag]]"}},
        page_tree: %PageTree{nodes: []},
        scope: scope
      })

    refute html =~ ~s(/#{scope.tenant.slug}/tags/)
    assert html =~ "[[#Unknown Tag]]"
  end

  test "render leaves unresolved canonical tag wikilinks as text" do
    scope = %Scope{tenant: %{name: "Cool Stuff", slug: "cool-stuff"}}

    html =
      render_component(&Markdown.render/1, %{
        block: %{id: "block-1", data: %{"text" => "[[tag:missing-tag]]"}},
        page_tree: %PageTree{nodes: []},
        scope: scope
      })

    refute html =~ ~s(/#{scope.tenant.slug}/tags/)
    assert html =~ "[[tag:missing-tag]]"
  end

  test "render sanitizes unsafe html" do
    html =
      render_component(&Markdown.render/1, %{
        block: %{
          id: "block-1",
          data: %{"text" => "<script>alert('xss')</script><img src=x onerror=alert(1)>"}
        },
        page_tree: %PageTree{nodes: []}
      })

    document = LazyHTML.from_fragment(html)

    refute document |> LazyHTML.query("script") |> Enum.any?()
    refute document |> LazyHTML.query("img") |> Enum.any?()
  end

  test "form_fields keeps the markdown source editable" do
    owner = generate(user())
    group = generate(group(author: owner))
    add_owner_membership(group, owner)
    user = generate(user())
    membership = add_membership(group, user, "alice")

    {:ok, tag} =
      Wik.Tags.create_tag("dance", "Dance", nil, scope: %Scope{actor: owner, tenant: group})

    wikilink_map = Jason.encode!(%{"Soups" => 1, "Soups/Vegetable Soup" => 2})

    html =
      render_component(&Markdown.form_fields/1, %{
        block: %{id: "block-1", data: %{"text" => "## Title"}},
        form:
          to_form(
            %{
              "text" => "## Title",
              "wikilink_map" => wikilink_map,
              "wikilink_member_map" => Jason.encode!(%{"alice" => membership.id}),
              "wikilink_tag_map" => Jason.encode!(%{"Dance" => tag.id})
            },
            as: :block
          ),
        page_tree: page_tree_fixture(group.id),
        scope: %Scope{tenant: group}
      })

    assert html =~ ~s(id="edit-block-markdown-textarea-block-1")
    assert html =~ ~s(name="block[text]")
    assert html =~ ~s(name="block[wikilink_map]")
    assert html =~ ~s(name="block[wikilink_member_map]")
    assert html =~ ~s(name="block[wikilink_tag_map]")
    assert html =~ ~s(data-wikilink-paths=)
    assert html =~ ~s(data-member-wikilink-usernames=)
    assert html =~ ~s(data-tag-wikilink-names=)
    assert html =~ "## Title"
    assert html =~ "&quot;Soups&quot;:1"
    assert html =~ "&quot;Soups/Vegetable Soup&quot;:2"
    assert html =~ "&quot;alice&quot;"
    assert html =~ "&quot;Dance&quot;"
  end

  defp add_membership(group, user, username) do
    membership =
      Ash.create!(
        GroupUserRelation,
        %{group_id: group.id, type: :member, user_id: user.id},
        authorize?: false,
        domain: Wik.Accounts
      )

    Ash.update!(
      membership,
      %{username: username},
      action: :set_username,
      scope: %Scope{actor: user, tenant: group}
    )
  end

  defp add_owner_membership(group, user) do
    Ash.create!(
      GroupUserRelation,
      %{group_id: group.id, type: :owner, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
  end

  defp page_tree_fixture(group_id \\ nil) do
    %PageTree{
      group_id: group_id,
      nodes: [
        %Node{
          id: 1,
          page_id: "11111111-1111-1111-1111-111111111111",
          parent_id: nil,
          slug: "soups",
          title: "Soups"
        },
        %Node{
          id: 2,
          page_id: "22222222-2222-2222-2222-222222222222",
          parent_id: 1,
          slug: "vegetable-soup",
          title: "Vegetable Soup"
        }
      ]
    }
  end
end
