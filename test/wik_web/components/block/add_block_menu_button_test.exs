defmodule WikWeb.Components.Block.AddBlockMenuButtonTest do
  use WikWeb.ConnCase, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]
  import Wik.TestGenerators

  alias Wik.Accounts.Membership
  alias Wik.Scope
  alias Wik.Wiki.Page
  alias WikWeb.Components.Block.AddBlockMenuButton

  test "render sends the selected add position with the open event" do
    html =
      render_component(&AddBlockMenuButton.render/1, %{
        event_open: "block:add_start",
        position: "top",
        class: "mb-12"
      })

    assert html =~ ~s(phx-click="block:add_start")
    assert html =~ ~s(phx-value-position="top")
    assert html =~ "Add block"
    assert html =~ "mb-12"
  end

  test "shows the child pages option when child pages are available" do
    actor = generate(user())
    space = generate(space())
    add_membership(space, actor, :member)
    grant_active_telegram_access(space, actor)
    scope = scope(actor, space)
    {:ok, source_page} = Page.create(authorize?: false, scope: scope)
    {:ok, child_page} = Page.create(authorize?: false, scope: scope)

    generate(
      page_tree(
        space: space,
        nodes: [
          %{id: 1, page_id: source_page.id, parent_id: nil, slug: "members", title: "Members"},
          %{id: 2, page_id: child_page.id, parent_id: 1, slug: "alice", title: "Alice"}
        ]
      )
    )

    html =
      render_component(&AddBlockMenuButton.modal_special_blocks/1, %{
        id: "special-blocks",
        event_cancel: "block:add_cancel",
        open?: true,
        scope: scope
      })

    assert html =~ ~s(data-testid="special-blocks")
    assert html =~ "YouTube"
    assert html =~ ~s(phx-value-type="youtube")
    assert html =~ "SoundCloud"
    assert html =~ ~s(phx-value-type="soundcloud")
    assert html =~ "Google Calendar"
    assert html =~ ~s(phx-value-type="google_calendar")
    assert html =~ "Google Maps"
    assert html =~ ~s(phx-value-type="google_maps")
    assert html =~ "Linked copy"
    assert html =~ ~s(phx-value-type="linked_copy")
    assert html =~ "Members"
    assert html =~ ~s(phx-value-type="members")
    assert html =~ "Rich text"
    assert html =~ ~s(phx-value-type="markdown")
    assert html =~ "Pages"
    assert html =~ ~s(phx-value-type="pages")
    assert html =~ "Child pages"
    assert html =~ ~s(phx-value-type="child_pages")
    refute html =~ "Top of page"
    refute html =~ "Bottom of page"
    refute html =~ ~s(phx-click="block:add_position_select")
  end

  test "hides the child pages option when no source pages are available" do
    actor = generate(user())
    space = generate(space())
    add_membership(space, actor, :member)
    grant_active_telegram_access(space, actor)
    scope = scope(actor, space)
    {:ok, leaf_page} = Page.create(authorize?: false, scope: scope)

    generate(
      page_tree(
        space: space,
        nodes: [
          %{id: 1, page_id: leaf_page.id, parent_id: nil, slug: "faq", title: "FAQ"}
        ]
      )
    )

    html =
      render_component(&AddBlockMenuButton.modal_special_blocks/1, %{
        id: "special-blocks",
        event_cancel: "block:add_cancel",
        open?: true,
        scope: scope
      })

    assert html =~ ~s(data-testid="special-blocks")
    assert html =~ "YouTube"
    assert html =~ ~s(phx-value-type="youtube")
    assert html =~ "SoundCloud"
    assert html =~ ~s(phx-value-type="soundcloud")
    assert html =~ "Google Calendar"
    assert html =~ ~s(phx-value-type="google_calendar")
    assert html =~ "Google Maps"
    assert html =~ ~s(phx-value-type="google_maps")
    assert html =~ "Linked copy"
    assert html =~ ~s(phx-value-type="linked_copy")
    assert html =~ "Members"
    assert html =~ ~s(phx-value-type="members")
    assert html =~ "Markdown"
    assert html =~ ~s(phx-value-type="markdown")
    assert html =~ "Pages"
    assert html =~ ~s(phx-value-type="pages")
    refute html =~ "Top of page"
    refute html =~ "Bottom of page"
    refute html =~ "Child pages"
  end

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
  end

  defp scope(actor, tenant) do
    %Scope{actor: actor, tenant: tenant}
  end
end
