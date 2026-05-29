defmodule WikWeb.TagGraphLiveTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Accounts.Membership
  alias Wik.Scope
  alias Wik.Tags
  alias Wik.Tags.Tagging

  test "renders root tags, creates and edits tags, links an existing child, and detaches a branch",
       %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    scope = scope(owner, space)

    {:ok, alpha} = Tags.create_tag("alpha", "Alpha", nil, scope: scope)
    {:ok, beta} = Tags.create_tag("beta", "Beta", nil, scope: scope)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/tags")

    assert has_element?(view, testid("tag-graph-page"))
    assert has_element?(view, testid("tag-branch-tag-path-#{alpha.id}"))
    assert has_element?(view, testid("tag-branch-tag-path-#{beta.id}"))
    assert has_element?(view, testid("tag-edit-mode-toggle"))
    refute has_element?(view, testid("tag-add-root"))

    render_click(element(view, testid("tag-edit-mode-toggle")))
    assert has_element?(view, testid("tag-edit-mode-ok"))

    render_click(element(view, testid("tag-add-root")))

    assert has_element?(view, testid("tag-detail-dialog"))

    render_submit(
      form(view, testid("tag-form-form"),
        form: %{"name" => "Partner dance", "description" => "Paired movement"}
      )
    )

    {:ok, child} = Tags.get_tag_by_slug("partner-dance", scope: scope)
    assert has_element?(view, testid("tag-branch-tag-path-#{child.id}"))
    refute has_element?(view, testid("tag-detail-#{child.id}"))

    render_click(element(view, testid("tag-edit-tag-path-#{child.id}")))
    assert has_element?(view, testid("tag-detail-#{child.id}"))

    render_click(element(view, testid("tag-detail-edit")))

    render_submit(
      form(view, testid("tag-form-form"),
        form: %{"name" => "Social dance", "description" => "Updated"}
      )
    )

    {:ok, child} = Tags.get_tag_by_slug("social-dance", scope: scope)

    render_click(element(view, testid("tag-edit-tag-path-#{alpha.id}")))
    assert has_element?(view, testid("tag-detail-#{alpha.id}"))

    render_click(element(view, testid("tag-link-child-start")))

    render_submit(form(view, testid("tag-link-form-form"), link: %{"target_tag_id" => child.id}))

    assert has_element?(view, testid("tag-branch-tag-path-#{alpha.id}__#{child.id}"))

    render_click(element(view, testid("tag-edit-tag-path-#{beta.id}")))
    assert has_element?(view, testid("tag-detail-#{beta.id}"))

    render_click(element(view, testid("tag-link-child-start")))

    render_submit(form(view, testid("tag-link-form-form"), link: %{"target_tag_id" => child.id}))

    assert has_element?(view, testid("tag-branch-tag-path-#{beta.id}__#{child.id}"))

    render_click(element(view, testid("tag-edit-tag-path-#{alpha.id}__#{child.id}")))
    assert has_element?(view, testid("tag-detail-#{child.id}"))
    assert has_element?(view, testid("tag-detail-jump-#{alpha.id}"))
    assert has_element?(view, testid("tag-detail-jump-#{beta.id}"))

    render_click(element(view, testid("tag-detach-tag-path-#{beta.id}__#{child.id}")))

    refute has_element?(view, testid("tag-branch-tag-path-#{beta.id}__#{child.id}"))
    assert has_element?(view, testid("tag-branch-tag-path-#{alpha.id}__#{child.id}"))
  end

  test "deleting a selected tag removes it from the rendered graph", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    scope = scope(owner, space)

    {:ok, root} = Tags.create_tag("dance", "Dance", nil, scope: scope)
    {:ok, child} = Tags.create_tag("partner-dance", "Partner dance", nil, scope: scope)
    assert {:ok, _edge} = Tags.link_tags(root.id, child.id, scope: scope)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/tags?#{%{tag: child.id}}")

    assert has_element?(view, testid("tag-detail-dialog"))
    assert has_element?(view, testid("tag-detail-#{child.id}"))
    refute has_element?(view, testid("tag-delete-tag-path-#{root.id}__#{child.id}"))

    render_click(element(view, testid("tag-edit-mode-toggle")))
    assert has_element?(view, testid("tag-edit-mode-ok"))

    assert has_element?(view, testid("tag-detail-delete"))
    render_click(element(view, testid("tag-detail-delete")))
    assert has_element?(view, testid("tag-delete-confirm"))
    render_click(element(view, testid("tag-delete-confirm-submit")))

    refute has_element?(view, testid("tag-branch-tag-path-#{root.id}__#{child.id}"))
    refute has_element?(view, testid("tag-detail-#{child.id}"))
  end

  test "read mode tag click navigates to the tag page", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    scope = scope(owner, space)

    {:ok, alpha} = Tags.create_tag("alpha", "Alpha", "Foundational rhythm", scope: scope)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/tags")

    refute has_element?(view, testid("tag-add-root"))

    render_click(element(view, testid("tag-select-tag-path-#{alpha.id}")))

    path = ~p"/#{space.slug}/tags/#{alpha.slug}"
    assert_redirect(view, path)
  end

  test "renders direct membership tagging counts next to tag names", %{conn: conn} do
    owner = generate(user())
    member_a = generate(user())
    member_b = generate(user())
    space = generate(space(author: owner))
    owner_membership = add_membership(space, owner, :owner)
    member_a_membership = add_membership(space, member_a, :member)
    member_b_membership = add_membership(space, member_b, :member)
    scope = scope(owner, space)

    {:ok, alpha} = Tags.create_tag("alpha", "Alpha", nil, scope: scope)
    {:ok, beta} = Tags.create_tag("beta", "Beta", nil, scope: scope)

    create_membership_tagging(member_a_membership, alpha, owner_membership, scope)
    create_membership_tagging(member_b_membership, alpha, owner_membership, scope)
    create_membership_tagging(member_a_membership, beta, owner_membership, scope)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/tags")

    assert has_element?(view, "#{testid("tag-count-tag-path-#{alpha.id}")}", "2")
    assert has_element?(view, "#{testid("tag-count-tag-path-#{beta.id}")}", "1")
  end

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
  end

  defp create_membership_tagging(target_membership, tag, tagged_by_membership, scope) do
    Ash.create!(
      Tagging,
      %{
        tag_id: tag.id,
        taggable_type: "membership",
        taggable_id: target_membership.id,
        tagged_by_membership_id: tagged_by_membership.id,
        dimensions: %{"interest" => 1},
        description: nil
      },
      authorize?: false,
      domain: Wik.Tags,
      action: :create,
      scope: scope
    )
  end

  defp log_in(conn, user) do
    {:ok, token, _claims} = Jwt.token_for_user(user)
    user = Ash.Resource.set_metadata(user, %{token: token})

    conn
    |> init_test_session(%{})
    |> AuthHelpers.store_in_session(user)
  end

  defp scope(actor, tenant), do: %Scope{actor: actor, tenant: tenant}
end
