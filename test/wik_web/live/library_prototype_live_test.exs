defmodule WikWeb.LibraryPrototypeLiveTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Accounts.Membership
  alias Wik.Scope
  alias Wik.Tags
  alias WikWeb.LibraryPrototypeLive.Schema
  alias WikWeb.LibraryPrototypeLive.State

  setup %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    membership = add_membership(space, owner, :owner)

    %{
      conn: log_in(conn, owner),
      membership: membership,
      owner: owner,
      space: space
    }
  end

  test "shows every entry in one feed with compact topic and type filters", %{
    conn: conn,
    owner: owner,
    space: space
  } do
    create_topic!(owner, space, "berlin", "Berlin")
    create_topic!(owner, space, "unassigned", "Unassigned")

    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries")

    assert has_element?(view, testid("library-page"))
    assert has_element?(view, testid("library-toolbar"))

    assert has_element?(
             view,
             testid("library-settings-open") <>
               ~s([popovertarget="library-settings-popover"][style="anchor-name:--library-settings-anchor"])
           )

    assert has_element?(
             view,
             ~s(#library-settings-popover[popover][style="position-anchor:--library-settings-anchor"])
           )

    assert has_element?(
             view,
             testid("topic-filter") <>
               ~s([popovertarget="topic-filter-popover"][style="anchor-name:--topic-filter-anchor"])
           )

    assert has_element?(
             view,
             ~s(#topic-filter-popover[popover][style="position-anchor:--topic-filter-anchor"])
           )

    assert has_element?(view, testid("type-filter") <> ~s([popovertarget="type-filter-popover"]))
    assert has_element?(view, "#type-filter-popover[popover]")
    assert has_element?(view, testid("topic-filter-berlin") <> " .hero-check-micro")
    refute has_element?(view, testid("topic-filter-unassigned"))
    assert has_element?(view, testid("type-filter-place") <> " .hero-check-micro")
    assert has_element?(view, testid("type-filter-video") <> " .hero-check-micro")
    assert has_element?(view, testid("entry-open-entry-place"))
    assert has_element?(view, testid("entry-open-entry-contact"))
    assert has_element?(view, testid("entry-open-entry-video"))
    assert has_element?(view, testid("entry-open-entry-music"))

    assert has_element?(
             view,
             testid("entry-open-entry-place") <>
               ~s( dt[title="Location"] .hero-map-pin-micro)
           )

    assert has_element?(
             view,
             testid("entry-open-entry-contact") <>
               ~s( dt[title="Organization"] .hero-home)
           )

    assert has_element?(
             view,
             testid("entry-open-entry-contact") <>
               ~s( dt[title="Role or title"] .hero-academic-cap)
           )

    refute has_element?(view, ~s([data-testid^="collection-"]))
  end

  test "combines OR topic filters with OR type filters across dimensions", %{
    conn: conn,
    owner: owner,
    space: space
  } do
    berlin = create_topic!(owner, space, "berlin", "Berlin")
    software = create_topic!(owner, space, "software", "Software")

    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries")

    view |> element(testid("topic-filter-berlin")) |> render_click()
    assert_patch(view, ~p"/#{space.slug}/libraries?#{%{topics: berlin.slug}}")
    assert has_element?(view, testid("topic-filter-berlin") <> " .hero-check-micro")
    assert has_element?(view, testid("topic-filter-software") <> " .hero-minus-micro")
    assert has_element?(view, testid("entry-open-entry-place"))
    refute has_element?(view, testid("entry-open-entry-video"))

    view |> element(testid("topic-filter-software")) |> render_click()

    assert_patch(
      view,
      ~p"/#{space.slug}/libraries?#{%{topics: Enum.join([berlin.slug, software.slug], ",")}}"
    )

    assert has_element?(view, testid("entry-open-entry-place"))
    assert has_element?(view, testid("entry-open-entry-video"))

    view |> element(testid("type-filter-video")) |> render_click()

    assert has_element?(view, testid("entry-open-entry-video"))
    refute has_element?(view, testid("entry-open-entry-place"))
  end

  test "adds an entry by choosing its type first", %{conn: conn, space: space} do
    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries")

    view |> element(testid("entry-create-open")) |> render_click()
    assert_patch(view, ~p"/#{space.slug}/libraries/entries/new")
    assert has_element?(view, testid("entry-type-picker"))

    view |> element(testid("entry-type-select-place")) |> render_click()
    assert has_element?(view, testid("entry-form"))

    view
    |> form(testid("entry-form"),
      entry: %{
        location: "Kreuzberg, Berlin",
        name: "My dance studio",
        notes: "Weekly community practice",
        phone: "",
        website: ""
      }
    )
    |> render_submit()

    assert has_element?(view, ~s([data-testid^="library-entry-detail-entry-"]))

    view |> element(testid("library-modal-close")) |> render_click()
    assert_patch(view, ~p"/#{space.slug}/libraries")

    assert has_element?(
             view,
             ~s(#library-entries [data-testid^="entry-open-entry-"] .badge-outline)
           )
  end

  test "members can dismiss an automatic topic and add their own relevance", %{
    conn: conn,
    owner: owner,
    space: space
  } do
    community = create_topic!(owner, space, "community", "Community")

    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries/entries/entry-place")

    assert has_element?(view, testid("entry-topic-detail-#{community.id}"))
    assert has_element?(view, testid("entry-topic-dismiss-#{community.id}"))

    view |> element(testid("entry-topic-dismiss-#{community.id}")) |> render_click()
    refute has_element?(view, testid("entry-topic-detail-#{community.id}"))

    view |> element(testid("entry-topic-add-open")) |> render_click()

    view
    |> form(testid("entry-topic-form"),
      entry_topic: %{relevancy: "6", topic_id: community.id}
    )
    |> render_submit()

    assert has_element?(view, testid("entry-topic-detail-#{community.id}"), "6/10")
    assert has_element?(view, testid("entry-topic-remove-#{community.id}"))
  end

  test "admins tune automatic matching with aliases and per-topic switches", %{
    conn: conn,
    owner: owner,
    space: space
  } do
    local = create_topic!(owner, space, "local-community", "Local community")

    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries/topic-matching")

    assert has_element?(view, testid("topic-matching-page"))
    assert has_element?(view, testid("topic-matching-rule-local-community"))

    view |> element(testid("topic-matching-expand-local-community")) |> render_click()

    view
    |> form(testid("topic-matching-alias-form-local-community"),
      topic_alias: %{value: "local-first"}
    )
    |> render_submit()

    assert has_element?(view, testid("topic-matching-alias-local-community"))

    render_patch(view, ~p"/#{space.slug}/libraries")
    assert has_element?(view, testid("entry-topic-entry-video-#{local.id}"))

    render_patch(view, ~p"/#{space.slug}/libraries/topic-matching")

    view
    |> element(testid("topic-matching-rule-toggle-local-community"))
    |> render_click()

    assert has_element?(
             view,
             testid("topic-matching-rule-toggle-local-community") <> ~s([aria-checked="false"])
           )
  end

  test "owners create a type, configure fields, and cannot delete a used type", %{
    conn: conn,
    space: space
  } do
    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries/types/new")

    view |> element(testid("template-select-custom")) |> render_click()

    view
    |> form(testid("type-create-form"),
      type: %{
        description: "People worth calling",
        entry_creation_permission: "members",
        name: "Useful people"
      }
    )
    |> render_submit()

    assert_patch(view, ~p"/#{space.slug}/libraries/types/useful-people/settings")

    view
    |> form(testid("field-form"),
      field: %{label: "Role", required: "false", type: "text"}
    )
    |> render_submit()

    assert has_element?(view, testid("schema-field-role"))

    {:ok, used_view, _html} =
      live(conn, ~p"/#{space.slug}/libraries/types/place/settings")

    assert has_element?(used_view, testid("type-delete-blocked"))
    assert has_element?(used_view, testid("type-delete") <> "[disabled]")
  end

  test "type schemas remain portable", %{conn: conn, space: space} do
    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries/types/video/settings")

    assert has_element?(view, testid("portable-schema"))
    assert has_element?(view, "#library-schema-json[readonly]")

    blueprint =
      State.new()
      |> State.find_type("contact")
      |> Schema.export()

    {:ok, import_view, _html} = live(conn, ~p"/#{space.slug}/libraries/types/new")

    import_view
    |> form(testid("schema-import-form"), schema: %{json: blueprint})
    |> render_submit()

    assert has_element?(import_view, testid("type-create-form"))
  end

  test "members can add entries but cannot open Library settings", %{space: space} do
    member = generate(user())
    add_membership(space, member, :member)
    grant_active_telegram_access(space, member)

    conn = Phoenix.ConnTest.build_conn() |> log_in(member)
    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries")

    assert has_element?(view, testid("entry-create-open"))
    refute has_element?(view, testid("library-settings-open"))

    assert {:error,
            {:live_redirect,
             %{
               to: redirect_path,
               flash: %{"error" => "Only space administrators can manage Library settings."}
             }}} =
             live(conn, ~p"/#{space.slug}/libraries/topic-matching")

    assert redirect_path == ~p"/#{space.slug}/libraries"
  end

  test "topic pages link back to the matching Library filter", %{
    conn: conn,
    owner: owner,
    space: space
  } do
    topic = create_topic!(owner, space, "social-dance", "Social dance")

    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/topics/#{topic.slug}")

    assert has_element?(
             view,
             testid("tag-library-link") <>
               ~s([href="/#{space.slug}/libraries?topics=#{topic.slug}"])
           )
  end

  defp create_topic!(owner, space, slug, name) do
    {:ok, topic} = Tags.create_tag(slug, name, scope: scope(owner, space))
    topic
  end

  defp scope(actor, tenant), do: %Scope{actor: actor, tenant: tenant}

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false
    )
  end

  defp log_in(conn, user) do
    {:ok, token, _claims} = Jwt.token_for_user(user)
    user = Ash.Resource.set_metadata(user, %{token: token})

    conn
    |> init_test_session(%{})
    |> AuthHelpers.store_in_session(user)
  end
end
