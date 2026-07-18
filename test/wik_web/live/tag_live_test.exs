defmodule WikWeb.TagLiveTest do
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
  alias Wik.Wiki

  test "tag page defaults to view mode and can be edited", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    scope = scope(owner, space)

    {:ok, tag} = Tags.create_tag("alpha", "Alpha", "Foundational rhythm", scope: scope)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/topics/#{tag.slug}")

    assert has_element?(view, testid("tag-page"))
    assert has_element?(view, testid("tag-edit-mode-toggle"))
    assert has_element?(view, testid("primary-block"))
    refute has_element?(view, testid("tag-form-form"))

    render_click(element(view, testid("tag-edit-mode-toggle")))

    assert has_element?(view, testid("tag-form-form"))

    render_submit(
      form(view, testid("tag-form-form"),
        form: %{"name" => "Social dance", "description" => "Updated description"}
      )
    )

    assert_patch(view, ~p"/#{space.slug}/topics/social-dance")
    assert has_element?(view, testid("tag-page"))
    refute has_element?(view, testid("tag-form-form"))

    assert {:ok, updated_tag} = Tags.get_tag_by_slug("social-dance", scope: scope)
    assert updated_tag.description == "Updated description"
  end

  test "tag page shows tagged members ordered by interest, then skill, then username", %{
    conn: conn
  } do
    owner = generate(user())
    first_user = generate(user())
    second_user = generate(user())
    third_user = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    first_membership =
      space
      |> add_membership(first_user, :member)
      |> then(&set_username(&1, "ada"))
      |> reload_membership()

    second_membership =
      space
      |> add_membership(second_user, :member)
      |> then(&set_username(&1, "bea"))
      |> reload_membership()

    third_membership =
      space
      |> add_membership(third_user, :member)
      |> then(&set_username(&1, "cy"))
      |> reload_membership()

    grant_active_telegram_access(space, owner)
    grant_active_telegram_access(space, first_user)
    grant_active_telegram_access(space, second_user)
    grant_active_telegram_access(space, third_user)

    owner_scope = scope(owner, space)
    first_scope = scope(first_user, space)
    second_scope = scope(second_user, space)
    third_scope = scope(third_user, space)

    {:ok, tag} = Tags.create_tag("fusion", "Fusion", "Late-night socials", scope: owner_scope)

    {:ok, first_tagging} =
      Tags.upsert_tagging(
        first_membership,
        first_membership,
        tag.id,
        %{dimensions: %{"interest" => 9, "skill" => 2}, description: "Hosts practice nights"},
        scope: first_scope
      )

    {:ok, second_tagging} =
      Tags.upsert_tagging(
        second_membership,
        second_membership,
        tag.id,
        %{dimensions: %{"interest" => 7, "skill" => 2}, description: "Weekend regular"},
        scope: second_scope
      )

    {:ok, third_tagging} =
      Tags.upsert_tagging(
        third_membership,
        third_membership,
        tag.id,
        %{dimensions: %{"interest" => 4, "skill" => 6}, description: nil},
        scope: third_scope
      )

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/topics/#{tag.slug}")

    assert has_element?(view, testid("tag-page"))
    assert has_element?(view, testid("tag-member-taggings-table"))
    assert has_element?(view, testid("tag-member-tagging-member-#{first_tagging.id}"))
    assert has_element?(view, testid("tag-member-tagging-member-#{second_tagging.id}"))
    assert has_element?(view, testid("tag-member-tagging-member-#{third_tagging.id}"))
    assert has_element?(view, testid("tag-member-tagging-interest-#{first_tagging.id}"))
    assert has_element?(view, testid("tag-member-tagging-skill-#{third_tagging.id}"))
    assert has_element?(view, testid("tag-member-tagging-description-#{first_tagging.id}"))
    assert has_element?(view, testid("tag-member-tagging-sort-controls"))

    assert has_element?(
             view,
             testid("tag-member-tagging-sort-interest") <> ~s([aria-pressed="true"])
           )

    refute has_element?(view, testid("tag-member-tagging-sort-username"))

    refute has_element?(view, ~s(.cinder-list button[phx-click="toggle_sort"]))

    html = render(view)

    assert index_of_testid(html, "tag-member-tagging-member-#{first_tagging.id}") <
             index_of_testid(html, "tag-member-tagging-member-#{second_tagging.id}")

    assert index_of_testid(html, "tag-member-tagging-member-#{second_tagging.id}") <
             index_of_testid(html, "tag-member-tagging-member-#{third_tagging.id}")

    render_click(element(view, testid("tag-member-tagging-sort-skill")))
    render_async(view)

    assert has_element?(
             view,
             testid("tag-member-tagging-sort-skill") <> ~s([aria-pressed="true"])
           )

    refute has_element?(
             view,
             testid("tag-member-tagging-sort-interest") <> ~s([aria-pressed="true"])
           )

    html = render(view)

    assert index_of_testid(html, "tag-member-tagging-member-#{third_tagging.id}") <
             index_of_testid(html, "tag-member-tagging-member-#{first_tagging.id}")

    render_click(element(view, testid("tag-member-tagging-open-#{first_tagging.id}")))

    assert_redirect(
      view,
      ~p"/#{space.slug}/wiki/members/#{first_membership.username}/tag/#{tag.slug}"
    )
  end

  test "tag page add-to-profile opens tagging form for the current topic", %{conn: conn} do
    owner = generate(user())
    user = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    membership =
      space
      |> add_membership(user, :member)
      |> then(&set_username(&1, "ada"))
      |> reload_membership()

    grant_active_telegram_access(space, user)
    owner_scope = scope(owner, space)
    member_scope = scope(user, space)

    {:ok, tag} = Tags.create_tag("fusion", "Fusion", nil, scope: owner_scope)

    {:ok, view, _html} =
      conn
      |> log_in(user)
      |> live(~p"/#{space.slug}/topics/#{tag.slug}")

    assert has_element?(view, testid("member-tagging-add"))

    render_click(element(view, testid("member-tagging-add")))

    assert has_element?(view, testid("member-tagging-dialog"))
    assert has_element?(view, testid("member-tagging-form-form"))

    assert has_element?(
             view,
             ~s(#member-tagging-form select[name="form[tag_id]"] option[value="#{tag.id}"]),
             "Fusion"
           )

    render_submit(
      form(view, testid("member-tagging-form-form"),
        form: %{
          "tag_id" => tag.id,
          "interest_level" => "8",
          "skill_level" => "3",
          "description" => "I like this topic"
        }
      )
    )

    assert {:ok, [tagging]} = Tags.list_taggings(membership, scope: member_scope)
    assert tagging.tag_id == tag.id
    assert tagging.description == "I like this topic"
    assert has_element?(view, testid("tag-member-taggings-table"))
    refute has_element?(view, testid("member-tagging-add"))
  end

  test "tag primary block history navigation renders the selected revision", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    scope = scope(owner, space)

    {:ok, tag} = Tags.create_tag("history", "History", nil, scope: scope)

    assert {:ok, _block} =
             Tags.update_primary_block(tag, %{"text" => "First revision"}, scope: scope)

    assert {:ok, tag} = Tags.get_tag(tag.id, scope: scope)

    assert {:ok, _block} =
             Tags.update_primary_block(tag, %{"text" => "Second revision"}, scope: scope)

    assert {:ok, tag} = Tags.get_tag(tag.id, scope: scope)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/topics/#{tag.slug}")

    assert has_element?(view, testid("markdown-block"), "Second revision")

    render_click(element(view, testid("primary-block-history-prev")))

    assert has_element?(view, testid("markdown-block"), "First revision")
    refute has_element?(view, testid("markdown-block"), "Second revision")
  end

  test "tag page lists tagged pages with relevancy", %{conn: conn} do
    assert_tag_page_pages_section_works(conn)
  end

  test "tag page lists upcoming external events inherited from tagged calendars", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    owner_membership = add_membership(space, owner, :owner)
    scope = scope(owner, space)

    {:ok, tag} = Tags.create_tag("fusion", "Fusion", nil, scope: scope)

    {:ok, subscription} =
      ExternalCalendarSubscription.create(
        %{ics_url: "https://calendar.example.test/community.ics"},
        scope: scope
      )

    assert {:ok, subscription} =
             ExternalCalendarSubscription.update_custom_name(
               subscription,
               %{custom_name: "Custom calendar"},
               scope: scope
             )

    assert {:ok, _tagging} =
             Tags.upsert_tagging(
               subscription,
               owner_membership,
               tag.id,
               %{dimensions: %{"relevancy" => 7}},
               scope: scope
             )

    upcoming_event = external_event_fixture(space, subscription, title: "Upcoming dance")
    past_event = external_event_fixture(space, subscription, starts_at: ~U[2020-01-01 18:00:00Z])

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/topics/#{tag.slug}")

    assert has_element?(view, testid("tag-events"))

    assert has_element?(
             view,
             ~s(a[href="/#{space.slug}/events?ext=#{upcoming_event.id}"][data-testid="event-open-external:#{upcoming_event.id}"])
           )

    assert has_element?(
             view,
             testid("tag-external-event-calendar-name-external:#{upcoming_event.id}"),
             "Custom calendar"
           )

    refute has_element?(
             view,
             testid("event-open-external:#{past_event.id}")
           )
  end

  defp assert_tag_page_pages_section_works(conn) do
    owner = generate(user())
    space = generate(space(author: owner))
    owner_membership = add_membership(space, owner, :owner)
    scope = scope(owner, space)

    {:ok, tag} = Tags.create_tag("fusion", "Fusion", nil, scope: scope)
    {:ok, _home_node, home_page} = Wiki.ensure_page_and_node_at_path("home", scope: scope)
    {:ok, _guide_node, guide_page} = Wiki.ensure_page_and_node_at_path("docs/guide", scope: scope)

    assert {:ok, _tagging} =
             Tags.upsert_tagging(
               home_page,
               owner_membership,
               tag.id,
               %{dimensions: %{"relevancy" => 7}},
               scope: scope
             )

    assert {:ok, _tagging} =
             Tags.upsert_tagging(
               guide_page,
               owner_membership,
               tag.id,
               %{dimensions: %{"relevancy" => 3}},
               scope: scope
             )

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/topics/#{tag.slug}")

    assert has_element?(view, testid("tag-pages"))
    assert has_element?(view, testid("tag-page-list"))

    assert has_element?(
             view,
             ~s(a[href="/#{space.slug}/wiki/home"][data-testid="tag-page-#{home_page.id}"])
           )

    assert has_element?(
             view,
             ~s(a[href="/#{space.slug}/wiki/docs/guide"][data-testid="tag-page-#{guide_page.id}"])
           )

    assert has_element?(view, testid("tag-page-relevancy-#{home_page.id}"))
    assert has_element?(view, testid("tag-page-relevancy-#{guide_page.id}"))
  end

  test "tag page uses breadcrumbs for parents and relationship components for children and descendants",
       %{
         conn: conn
       } do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    scope = scope(owner, space)

    {:ok, parent} = Tags.create_tag("dance", "Dance", nil, scope: scope)
    {:ok, current} = Tags.create_tag("partner-dance", "Partner dance", nil, scope: scope)
    {:ok, child} = Tags.create_tag("tango", "Tango", nil, scope: scope)
    {:ok, grandchild} = Tags.create_tag("argentine-tango", "Argentine tango", nil, scope: scope)

    assert {:ok, _edge} = Tags.link_tags(parent.id, current.id, scope: scope)
    assert {:ok, _edge} = Tags.link_tags(current.id, child.id, scope: scope)
    assert {:ok, _edge} = Tags.link_tags(child.id, grandchild.id, scope: scope)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/topics/#{current.slug}")

    assert has_element?(view, testid("tag-breadcrumbs"))
    assert has_element?(view, testid("tag-breadcrumbs-path-0"))
    # assert has_element?(view, testid("tag-children"))
    # assert has_element?(view, testid("tag-children-jump-#{child.id}"))
    assert has_element?(view, testid("tag-descendants"))
    assert has_element?(view, testid("tag-branch-tag-path-#{current.id}__#{child.id}"))

    assert has_element?(
             view,
             testid("tag-branch-tag-path-#{current.id}__#{child.id}__#{grandchild.id}")
           )
  end

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
  end

  defp log_in(conn, user) do
    {:ok, token, _claims} = Jwt.token_for_user(user)
    user = Ash.Resource.set_metadata(user, %{token: token})

    conn
    |> init_test_session(%{})
    |> AuthHelpers.store_in_session(user)
  end

  defp set_username(membership, username) do
    Ash.update!(
      membership,
      %{username: username},
      action: :set_username,
      authorize?: false,
      domain: Wik.Accounts
    )
  end

  defp reload_membership(membership) do
    membership.space_id
    |> Wik.Accounts.get_membership(membership.user_id)
    |> elem(1)
  end

  defp index_of_testid(html, testid) do
    case :binary.match(html, ~s(data-testid="#{testid}")) do
      {index, _length} -> index
      :nomatch -> nil
    end
  end

  defp external_event_fixture(space, subscription, attrs) do
    default_starts_at =
      Date.utc_today()
      |> Date.add(7)
      |> DateTime.new!(~T[18:00:00], "Etc/UTC")
      |> with_usec_precision()

    starts_at = attrs |> Keyword.get(:starts_at, default_starts_at) |> with_usec_precision()

    ends_at =
      attrs |> Keyword.get(:ends_at, DateTime.add(starts_at, 2, :hour)) |> with_usec_precision()

    Repo.insert!(%ExternalEvent{
      id: Ash.UUIDv7.generate(),
      all_day: false,
      calendar_name: "Community calendar",
      description: "Imported from an external calendar",
      ends_at: ends_at,
      event_url: nil,
      external_occurrence_key: "single-#{Ash.UUIDv7.generate()}",
      external_recurrence_id: nil,
      external_uid: "external-#{Ash.UUIDv7.generate()}",
      last_seen_at: DateTime.utc_now(),
      location: "Riverside Hall",
      space_id: space.id,
      starts_at: starts_at,
      status: :published,
      subscription_id: subscription.id,
      title: Keyword.get(attrs, :title, "External event"),
      tz: "Etc/UTC"
    })
  end

  defp with_usec_precision(datetime), do: %{datetime | microsecond: {0, 6}}

  defp scope(actor, tenant), do: %Scope{actor: actor, tenant: tenant}
end
