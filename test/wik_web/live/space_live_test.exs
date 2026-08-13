defmodule WikWeb.SpaceLiveTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Activity.Recorder
  alias Wik.Accounts.Membership
  alias Wik.Events.Event
  alias Wik.Tags
  alias Wik.Wiki.Page

  test "shows the resource count for each space section", %{conn: conn} do
    owner = generate(user())
    member = generate(user())
    space = generate(space(author: owner))
    scope = scope(owner, space)

    add_membership(space, owner, :owner)
    add_membership(space, member, :member)

    assert {:ok, _page} = Page.create(scope: scope)
    assert {:ok, _tag} = Tags.create_tag("announcements", "Announcements", scope: scope)

    assert {:ok, _event} =
             Ash.create(
               Event,
               %{
                 all_day: false,
                 ends_at_time: "20:00",
                 ends_on: future_date_string(30),
                 location: "Community Hall",
                 starts_at_time: "18:00",
                 starts_on: future_date_string(30),
                 title: "Community dinner",
                 tz: "Etc/UTC"
               },
               action: :create,
               scope: scope
             )

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}")

    render_async(view)

    assert has_element?(view, "a[href='/#{space.slug}/wiki']", "1")
    assert has_element?(view, "a[href='/#{space.slug}/members']", "2")
    assert has_element?(view, "a[href='/#{space.slug}/topics']", "1")
    assert has_element?(view, "a[href='/#{space.slug}/events']", "1")
  end

  test "shows an activity preview outside the editable space zone", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    membership = add_membership(space, owner, :owner)
    subject_id = Ash.UUIDv7.generate()

    assert {:ok, entry} =
             Recorder.record(activity_attrs(space, membership, subject_id, :wiki, :page_updated))

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}")

    assert has_element?(view, "#space-activity-preview")
    assert has_element?(view, "#space-activity-view-all[href='/#{space.slug}/activity']")
    assert has_element?(view, testid("activity-entry-#{entry.id}"))
    refute has_element?(view, ".stacked #space-activity-section")
  end

  test "filters the full activity page with URL-backed category buttons", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    membership = add_membership(space, owner, :owner)
    wiki_subject_id = Ash.UUIDv7.generate()
    event_subject_id = Ash.UUIDv7.generate()

    assert {:ok, wiki_entry} =
             Recorder.record(
               activity_attrs(space, membership, wiki_subject_id, :wiki, :page_updated)
             )

    assert {:ok, event_entry} =
             Recorder.record(
               activity_attrs(space, membership, event_subject_id, :events, :event_created)
             )

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/activity")

    render_async(view)

    assert has_element?(view, "#space-activity-table")
    assert has_element?(view, testid("activity-category-all") <> ~s([aria-current="page"]))
    assert has_element?(view, testid("activity-entry-#{wiki_entry.id}"))
    assert has_element?(view, testid("activity-entry-#{event_entry.id}"))

    view |> element(testid("activity-category-events")) |> render_click()

    assert_patch(view, ~p"/#{space.slug}/activity?category=events")
    render_async(view)
    assert has_element?(view, testid("activity-category-events") <> ~s([aria-current="page"]))
    assert has_element?(view, testid("activity-entry-#{event_entry.id}"))
    refute has_element?(view, testid("activity-entry-#{wiki_entry.id}"))
  end

  test "treats an invalid update category as all", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live("/#{space.slug}/activity?category=unknown")

    assert has_element?(view, testid("activity-category-all") <> ~s([aria-current="page"]))
  end

  test "refreshes the overview when activity is published", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    membership = add_membership(space, owner, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}")

    render_async(view)

    assert {:ok, entry} =
             Recorder.record(
               activity_attrs(
                 space,
                 membership,
                 Ash.UUIDv7.generate(),
                 :events,
                 :event_created
               )
             )

    _ = :sys.get_state(view.pid)
    render_async(view)

    assert has_element?(view, testid("activity-entry-#{entry.id}"))
  end

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false
    )
  end

  defp activity_attrs(space, membership, subject_id, category, kind) do
    %{
      actor_label: to_string(membership.user_id),
      actor_membership_id: membership.id,
      category: category,
      kind: kind,
      metadata: %{},
      space_id: space.id,
      subject_id: subject_id,
      subject_label: "Activity subject",
      subject_path: nil,
      subject_type: if(category == :events, do: :event, else: :page)
    }
  end

  defp scope(actor, tenant), do: %Wik.Scope{actor: actor, tenant: tenant}

  defp log_in(conn, user) do
    {:ok, token, _claims} = Jwt.token_for_user(user)
    user = Ash.Resource.set_metadata(user, %{token: token})

    conn
    |> init_test_session(%{})
    |> AuthHelpers.store_in_session(user)
  end
end
