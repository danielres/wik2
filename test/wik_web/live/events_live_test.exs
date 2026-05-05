defmodule WikWeb.EventsLiveTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Accounts.GroupUserRelation
  alias Wik.Events

  require Ash.Query

  test "group members can view the compact timeline and open event detail by query param", %{
    conn: conn
  } do
    owner = generate(user())
    member = generate(user())
    group = generate(group(author: owner))

    add_membership(group, owner, :owner)
    add_membership(group, member, :member)
    grant_active_telegram_access(group, member)

    {:ok, _event} =
      Events.create_event(event_attrs(title: "Shared dinner"), scope: scope(owner, group))

    [publication] =
      Ash.read!(
        Wik.Events.EventPublication,
        authorize?: false,
        domain: Wik.Events,
        scope: scope(owner, group)
      )

    {:ok, view, _html} =
      conn
      |> log_in(member)
      |> live(~p"/#{group.name}/events")

    assert has_element?(view, testid("events-page"))
    assert has_element?(view, testid("event-publication-#{publication.id}"))
    refute render(view) =~ "An event description"
    refute has_element?(view, testid("events-create-button"))

    render_click(element(view, testid("event-open-#{publication.id}")))

    assert_patch(view, ~p"/#{group.name}/events?#{%{event: publication.id}}")
    assert has_element?(view, testid("event-detail"))
    assert render(view) =~ "An event description"
    assert render(view) =~ "Community Hall, 123 Example Street"
  end

  test "owner can create an event from the modal", %{conn: conn} do
    owner = generate(user())
    group = generate(group(author: owner))
    add_membership(group, owner, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{group.name}/events")

    render_click(element(view, testid("events-create-button")))

    assert has_element?(view, testid("event-modal-dialog"))
    refute render(view) =~ ~s(name="form[location_text]")

    render_submit(
      form(view, testid("event-form"),
        form: %{
          "title" => "Community dinner",
          "description" => "Bring food to share",
          "location" => "Community Hall",
          "all_day" => "false",
          "starts_on" => "2026-05-12",
          "starts_at_time" => "18:00",
          "ends_on" => "2026-05-12",
          "ends_at_time" => "20:00",
          "relay_policy" => "admins_only_groups",
          "provenance_policy" => "visible",
          "tz" => "Etc/UTC"
        }
      )
    )

    assert_patch(view, ~p"/#{group.name}/events")
    assert has_element?(view, testid("events-timeline"))
    refute has_element?(view, testid("event-form"))
    refute has_element?(view, testid("event-detail"))

    assert %Wik.Events.Event{} =
             Wik.Events.Event
             |> Ash.Query.filter(title == "Community dinner")
             |> Ash.read_one!(authorize?: false, domain: Wik.Events, scope: scope(owner, group))
  end

  test "create submit shows field errors without a flash", %{conn: conn} do
    owner = generate(user())
    group = generate(group(author: owner))
    add_membership(group, owner, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{group.name}/events")

    render_click(element(view, testid("events-create-button")))

    render_submit(
      form(view, testid("event-form"),
        form: %{
          "title" => "Community dinner",
          "description" => "Bring food to share",
          "location" => "",
          "all_day" => "false",
          "starts_on" => "2026-05-12",
          "starts_at_time" => "18:00",
          "ends_on" => "2026-05-12",
          "ends_at_time" => "20:00",
          "relay_policy" => "admins_only_groups",
          "provenance_policy" => "visible",
          "tz" => "Etc/UTC"
        }
      )
    )

    assert has_element?(view, "#event-form input[name='form[location]'].input-error")
    refute render(view) =~ "Could not save the event"
  end

  test "owner can change status only in edit mode inside the detail modal", %{
    conn: conn
  } do
    owner = generate(user())
    group = generate(group(author: owner))
    add_membership(group, owner, :owner)

    {:ok, event} =
      Events.create_event(
        event_attrs(title: "Community dinner", relay_policy: :admins_only_groups),
        scope: scope(owner, group)
      )

    {:ok, publication} =
      Wik.Events.EventPublication
      |> Ash.Query.filter(event_id == ^event.id and target_group_id == ^group.id)
      |> Ash.read_first(authorize?: false, domain: Wik.Events, scope: scope(owner, group))

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{group.name}/events")

    assert has_element?(view, testid("event-publication-#{publication.id}"))
    refute render(view) =~ ~s(name="form[status]")

    render_click(element(view, testid("event-open-#{publication.id}")))
    assert_patch(view, ~p"/#{group.name}/events?#{%{event: publication.id}}")
    assert has_element?(view, testid("event-detail"))

    render_click(element(view, testid("event-detail-edit-#{publication.id}")))
    assert has_element?(view, testid("event-form"))
    assert render(view) =~ ~s(name="form[status]")

    render_submit(
      form(view, testid("event-form"),
        form: %{
          "title" => "Community dinner updated",
          "description" => "Bring extra plates",
          "location" => "Community Hall, 123 Example Street",
          "all_day" => "false",
          "starts_on" => "2026-05-12",
          "starts_at_time" => "18:30",
          "ends_on" => "2026-05-12",
          "ends_at_time" => "20:30",
          "relay_policy" => "admins_only_groups",
          "provenance_policy" => "visible",
          "status" => "cancelled",
          "tz" => "Etc/UTC"
        }
      )
    )

    assert_patch(view, ~p"/#{group.name}/events")
    refute has_element?(view, testid("event-form"))
    refute has_element?(view, testid("event-detail"))
    assert render(view) =~ "Community dinner updated"
    assert render(view) =~ "cancelled"
  end

  test "edit submit shows field errors without a flash", %{conn: conn} do
    owner = generate(user())
    group = generate(group(author: owner))
    add_membership(group, owner, :owner)

    {:ok, event} =
      Events.create_event(
        event_attrs(title: "Community dinner", relay_policy: :admins_only_groups),
        scope: scope(owner, group)
      )

    {:ok, publication} =
      Wik.Events.EventPublication
      |> Ash.Query.filter(event_id == ^event.id and target_group_id == ^group.id)
      |> Ash.read_first(authorize?: false, domain: Wik.Events, scope: scope(owner, group))

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{group.name}/events")

    render_click(element(view, testid("event-open-#{publication.id}")))
    render_click(element(view, testid("event-detail-edit-#{publication.id}")))

    render_submit(
      form(view, testid("event-form"),
        form: %{
          "title" => "Community dinner updated",
          "description" => "Bring extra plates",
          "location" => "",
          "all_day" => "false",
          "starts_on" => "2026-05-12",
          "starts_at_time" => "18:30",
          "ends_on" => "2026-05-12",
          "ends_at_time" => "20:30",
          "relay_policy" => "admins_only_groups",
          "provenance_policy" => "visible",
          "status" => "published",
          "tz" => "Etc/UTC"
        }
      )
    )

    assert has_element?(view, "#event-form input[name='form[location]'].input-error")
    refute render(view) =~ "Could not save the event"
  end

  test "all-day toggle keeps timed values and provenance hidden suppresses relay context", %{
    conn: conn
  } do
    owner = generate(user())
    relay_owner = generate(user())
    origin_group = generate(group(author: owner))
    target_group = generate(group(author: relay_owner))

    add_membership(origin_group, owner, :owner)
    add_membership(origin_group, relay_owner, :admin)
    add_membership(target_group, relay_owner, :owner)
    grant_active_telegram_access(origin_group, relay_owner)

    {:ok, event} =
      Events.create_event(
        event_attrs(
          title: "Quiet walk",
          provenance_policy: :hidden,
          relay_policy: :admins_only_groups
        ),
        scope: scope(owner, origin_group)
      )

    {:ok, _publication} =
      Events.relay_event_to_group(event, target_group,
        scope: scope(relay_owner, origin_group),
        relay_note: "Good fit for your group"
      )

    {:ok, view, _html} =
      conn
      |> log_in(relay_owner)
      |> live(~p"/#{target_group.name}/events")

    refute render(view) =~ "Good fit for your group"
    refute render(view) =~ origin_group.name

    render_click(element(view, testid("events-create-button")))

    render_change(
      form(view, testid("event-form"),
        form: %{
          "title" => "",
          "description" => "",
          "location" => "",
          "all_day" => "true",
          "starts_on" => "2026-05-13",
          "ends_on" => "2026-05-14",
          "relay_policy" => "internal_only",
          "provenance_policy" => "visible",
          "tz" => "Etc/UTC"
        }
      )
    )

    render_change(
      form(view, testid("event-form"),
        form: %{
          "title" => "",
          "description" => "",
          "location" => "",
          "all_day" => "false",
          "starts_on" => "2026-05-13",
          "ends_on" => "2026-05-14",
          "relay_policy" => "internal_only",
          "provenance_policy" => "visible",
          "tz" => "Etc/UTC"
        }
      )
    )

    render_change(
      form(view, testid("event-form"),
        form: %{
          "title" => "",
          "description" => "",
          "location" => "",
          "all_day" => "false",
          "starts_on" => "2026-05-13",
          "starts_at_time" => "14:00",
          "ends_on" => "2026-05-14",
          "ends_at_time" => "16:00",
          "relay_policy" => "internal_only",
          "provenance_policy" => "visible",
          "tz" => "Etc/UTC"
        }
      )
    )

    html = render(view)
    assert html =~ ~s(id="event-starts-on")
    assert html =~ ~s(id="event-ends-on")
    assert html =~ ~s(id="event-starts-at-time")
    assert html =~ ~s(id="event-ends-at-time")
    assert html =~ ~s(type="time")
  end

  test "validate keeps all-day and timed date inputs stable while editing other fields", %{
    conn: conn
  } do
    owner = generate(user())
    group = generate(group(author: owner))
    add_membership(group, owner, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{group.name}/events")

    render_click(element(view, testid("events-create-button")))

    render_change(
      form(view, testid("event-form"),
        form: %{
          "title" => "",
          "description" => "",
          "location" => "",
          "all_day" => "true",
          "starts_on" => "2026-05-13",
          "ends_on" => "2026-05-14",
          "relay_policy" => "internal_only",
          "provenance_policy" => "visible",
          "tz" => "Etc/UTC"
        }
      )
    )

    render_change(
      form(view, testid("event-form"),
        form: %{
          "title" => "Quiet walk",
          "description" => "",
          "location" => "",
          "all_day" => "true",
          "starts_on" => "2026-05-13",
          "ends_on" => "2026-05-14",
          "relay_policy" => "internal_only",
          "provenance_policy" => "visible",
          "tz" => "Etc/UTC"
        }
      )
    )

    assert has_element?(view, "#event-starts-on[value='2026-05-13']")
    assert has_element?(view, "#event-ends-on[value='2026-05-14']")

    render_change(
      form(view, testid("event-form"),
        form: %{
          "title" => "Quiet walk",
          "description" => "",
          "location" => "",
          "all_day" => "false",
          "starts_on" => "2026-05-13",
          "ends_on" => "2026-05-14",
          "relay_policy" => "internal_only",
          "provenance_policy" => "visible",
          "tz" => "Etc/UTC"
        }
      )
    )

    render_change(
      form(view, testid("event-form"),
        form: %{
          "title" => "Quiet walk",
          "description" => "",
          "location" => "",
          "all_day" => "false",
          "starts_on" => "2026-05-13",
          "starts_at_time" => "14:00",
          "ends_on" => "2026-05-14",
          "ends_at_time" => "16:00",
          "relay_policy" => "internal_only",
          "provenance_policy" => "visible",
          "tz" => "Etc/UTC"
        }
      )
    )

    render_change(
      form(view, testid("event-form"),
        form: %{
          "title" => "Quiet walk updated",
          "description" => "",
          "location" => "",
          "all_day" => "false",
          "starts_on" => "2026-05-13",
          "starts_at_time" => "14:00",
          "ends_on" => "2026-05-14",
          "ends_at_time" => "16:00",
          "relay_policy" => "internal_only",
          "provenance_policy" => "visible",
          "tz" => "Etc/UTC"
        }
      )
    )

    assert has_element?(view, "#event-starts-on[value='2026-05-13']")
    assert has_element?(view, "#event-ends-on[value='2026-05-14']")
    assert has_element?(view, "#event-starts-at-time[value='14:00']")
    assert has_element?(view, "#event-ends-at-time[value='16:00']")
  end

  test "renders both event tz and user tz when they differ", %{conn: conn} do
    owner = generate(user())
    member = generate(user())
    group = generate(group(author: owner))

    add_membership(group, owner, :owner)
    add_membership(group, member, :member)
    grant_active_telegram_access(group, member)

    {:ok, _event} =
      Events.create_event(
        event_attrs(
          title: "Berlin dinner",
          starts_on: "2026-05-12",
          starts_at_time: "18:00",
          ends_on: "2026-05-12",
          ends_at_time: "20:00",
          tz: "Europe/Berlin"
        ),
        scope: scope(owner, group)
      )

    {:ok, view, _html} =
      conn
      |> log_in(member)
      |> live(~p"/#{group.name}/events")

    html = render(view)
    assert html =~ "Europe/Berlin"
    assert html =~ "Etc/UTC"
  end

  defp add_membership(group, user, type) do
    Ash.create!(
      GroupUserRelation,
      %{group_id: group.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
  end

  defp event_attrs(overrides) do
    %{
      all_day: false,
      description: "An event description",
      ends_at_time: "20:00",
      ends_on: "2026-05-10",
      location: "Community Hall, 123 Example Street",
      provenance_policy: :visible,
      relay_policy: :internal_only,
      starts_at_time: "18:00",
      starts_on: "2026-05-10",
      tz: "Etc/UTC",
      title: "Shared Dinner"
    }
    |> Map.merge(Enum.into(overrides, %{}))
  end

  defp scope(actor, tenant) do
    %Wik.Scope{actor: actor, tenant: tenant}
  end

  defp log_in(conn, user) do
    {:ok, token, _claims} = Jwt.token_for_user(user)
    user = Ash.Resource.set_metadata(user, %{token: token})

    conn
    |> init_test_session(%{})
    |> AuthHelpers.store_in_session(user)
  end
end
