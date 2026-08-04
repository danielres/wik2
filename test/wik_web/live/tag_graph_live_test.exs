defmodule WikWeb.TagGraphLiveTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Accounts.Membership
  alias Wik.Events.ExternalCalendarSubscription
  alias Wik.Events.ExternalEvent
  alias Wik.Repo
  alias Wik.Scope
  alias Wik.Tags
  alias Wik.Tags.Tagging
  alias Wik.Wiki

  test "renders root tags, creates and edits tags, links an existing child, and detaches a branch",
       %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    scope = scope(owner, space)

    {:ok, alpha} = Tags.create_tag("alpha", "Alpha", scope: scope)
    {:ok, beta} = Tags.create_tag("beta", "Beta", scope: scope)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/topics")

    assert has_element?(view, testid("tag-graph-page"))
    assert has_element?(view, testid("tag-branch-tag-path-#{alpha.id}"))
    assert has_element?(view, testid("tag-branch-tag-path-#{beta.id}"))
    assert has_element?(view, testid("tag-edit-mode-toggle"))
    refute has_element?(view, testid("tag-add-root"))

    render_click(element(view, testid("tag-edit-mode-toggle")))
    assert has_element?(view, testid("tag-edit-mode-ok"))

    render_click(element(view, testid("tag-add-root")))

    assert has_element?(view, testid("tag-detail-dialog"))

    render_submit(form(view, testid("tag-form-form"), form: %{"name" => "Partner dance"}))

    {:ok, child} = Tags.get_tag_by_slug("partner-dance", scope: scope)
    assert has_element?(view, testid("tag-branch-tag-path-#{child.id}"))
    refute has_element?(view, testid("tag-detail-#{child.id}"))

    render_click(element(view, testid("tag-edit-tag-path-#{child.id}")))
    assert has_element?(view, testid("tag-detail-#{child.id}"))

    render_click(element(view, testid("tag-detail-edit")))

    render_submit(form(view, testid("tag-form-form"), form: %{"name" => "Social dance"}))

    {:ok, child} = Tags.get_tag_by_slug("social-dance", scope: scope)

    render_click(element(view, testid("tag-edit-tag-path-#{alpha.id}")))
    assert has_element?(view, testid("tag-detail-#{alpha.id}"))

    render_click(element(view, testid("tag-link-child-start")))
    assert has_element?(view, testid("tag-link-target-tag"), "Topic")
    assert has_element?(view, testid("tag-link-submit"), "Link topic")

    render_submit(form(view, testid("tag-link-form-form"), link: %{"target_tag_id" => ""}))
    assert has_element?(view, testid("tag-link-form"), "Please select a topic.")

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

    {:ok, root} = Tags.create_tag("dance", "Dance", scope: scope)
    {:ok, child} = Tags.create_tag("partner-dance", "Partner dance", scope: scope)
    assert {:ok, _edge} = Tags.link_tags(root.id, child.id, scope: scope)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/topics?#{%{tag: child.id}}")

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

    {:ok, alpha} = Tags.create_tag("alpha", "Alpha", scope: scope)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/topics")

    refute has_element?(view, testid("tag-add-root"))

    render_click(element(view, testid("tag-select-tag-path-#{alpha.id}")))

    path = ~p"/#{space.slug}/topics/#{alpha.slug}"
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

    {:ok, alpha} = Tags.create_tag("alpha", "Alpha", scope: scope)
    {:ok, beta} = Tags.create_tag("beta", "Beta", scope: scope)

    create_membership_tagging(member_a_membership, alpha, owner_membership, scope, %{
      "interest" => 4,
      "skill" => 0
    })

    create_membership_tagging(member_b_membership, alpha, owner_membership, scope, %{
      "interest" => 7,
      "skill" => 6
    })

    create_membership_tagging(member_a_membership, beta, owner_membership, scope, %{
      "interest" => 3,
      "skill" => 2
    })

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/topics")

    assert has_element?(view, "#{testid("tag-count-tag-path-#{alpha.id}")}", "2")
    assert has_element?(view, "#{testid("tag-count-tag-path-#{beta.id}")}", "1")

    alpha_modal_html =
      view
      |> element("#tag-path-#{alpha.id}-members-count-details-modal_portal")
      |> render()

    assert alpha_modal_html =~ ~s(data-testid="tag-interest-chart-tag-path-#{alpha.id}")
    assert alpha_modal_html =~ ~s(data-testid="tag-skill-chart-tag-path-#{alpha.id}")
  end

  test "renders page tagging counts and opens a modal with tagged pages", %{conn: conn} do
    assert_page_count_modal_works(conn)
  end

  test "renders upcoming external event counts inherited from subscription topics", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    owner_membership = add_membership(space, owner, :owner)
    scope = scope(owner, space)

    {:ok, alpha} = Tags.create_tag("alpha", "Alpha", scope: scope)

    {:ok, subscription} =
      Ash.create(
        ExternalCalendarSubscription,
        %{ics_url: "https://calendar.example.test/community.ics"},
        action: :create,
        scope: scope
      )

    create_subscription_tagging(subscription, alpha, owner_membership, scope)

    upcoming_date = Date.utc_today() |> Date.add(7)
    next_upcoming_date = Date.utc_today() |> Date.add(8)
    past_date = Date.utc_today() |> Date.add(-7)

    create_external_event(subscription, "external-dinner", starts_at(upcoming_date))
    create_external_event(subscription, "external-social", starts_at(next_upcoming_date))
    create_external_event(subscription, "past-external-dinner", starts_at(past_date))

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/topics")

    assert has_element?(view, "#{testid("tag-event-count-tag-path-#{alpha.id}")}", "2")
  end

  defp assert_page_count_modal_works(conn) do
    owner = generate(user())
    space = generate(space(author: owner))
    owner_membership = add_membership(space, owner, :owner)
    scope = scope(owner, space)

    {:ok, alpha} = Tags.create_tag("alpha", "Alpha", scope: scope)
    {:ok, _home_node, home_page} = Wiki.ensure_page_and_node_at_path("home", scope: scope)
    {:ok, _guide_node, guide_page} = Wiki.ensure_page_and_node_at_path("docs/guide", scope: scope)

    create_page_tagging(home_page, alpha, owner_membership, scope)
    create_page_tagging(guide_page, alpha, owner_membership, scope)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/topics")

    assert has_element?(view, "#{testid("tag-page-count-tag-path-#{alpha.id}")}", "2")

    page_modal_html =
      view
      |> element("#tag-path-#{alpha.id}-pages-count-details-modal_portal")
      |> render()

    assert page_modal_html =~ ~s(data-testid="tag-page-list-tag-path-#{alpha.id}")
    assert page_modal_html =~ ~s(href="/#{space.slug}/wiki/home")
    assert page_modal_html =~ ~s(href="/#{space.slug}/wiki/docs/guide")
  end

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
  end

  defp create_membership_tagging(
         target_membership,
         tag,
         tagged_by_membership,
         scope,
         dimensions
       ) do
    Ash.create!(
      Tagging,
      %{
        tag_id: tag.id,
        taggable_type: "membership",
        taggable_id: target_membership.id,
        tagged_by_membership_id: tagged_by_membership.id,
        dimensions: dimensions,
        description: nil
      },
      authorize?: false,
      domain: Wik.Tags,
      action: :create,
      scope: scope
    )
  end

  defp create_page_tagging(page, tag, tagged_by_membership, scope) do
    Ash.create!(
      Tagging,
      %{
        tag_id: tag.id,
        taggable_type: "page",
        taggable_id: page.id,
        tagged_by_membership_id: tagged_by_membership.id,
        dimensions: %{"relevancy" => 5},
        description: nil
      },
      authorize?: false,
      domain: Wik.Tags,
      action: :create,
      scope: scope
    )
  end

  defp create_subscription_tagging(subscription, tag, tagged_by_membership, scope) do
    Ash.create!(
      Tagging,
      %{
        tag_id: tag.id,
        taggable_type: "external_calendar_subscription",
        taggable_id: subscription.id,
        tagged_by_membership_id: tagged_by_membership.id,
        dimensions: %{"relevancy" => 5},
        description: nil
      },
      authorize?: false,
      domain: Wik.Tags,
      action: :create,
      scope: scope
    )
  end

  defp create_external_event(subscription, uid, starts_at) do
    Repo.insert!(%ExternalEvent{
      space_id: subscription.space_id,
      subscription_id: subscription.id,
      external_uid: uid,
      external_occurrence_key: uid,
      title: uid,
      starts_at: starts_at,
      ends_at: DateTime.add(starts_at, 2, :hour),
      tz: "Etc/UTC",
      last_seen_at: DateTime.utc_now()
    })
  end

  defp starts_at(date) do
    DateTime.new!(date, ~T[18:00:00.000000], "Etc/UTC")
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
