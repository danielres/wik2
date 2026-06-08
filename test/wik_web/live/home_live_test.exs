defmodule WikWeb.HomeLiveTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Accounts
  alias Wik.Accounts.Membership
  alias Wik.Events
  alias Wik.Events.Event
  alias Wik.Events.EventPublication
  alias Wik.Events.ExternalCalendarSubscription
  alias Wik.Events.ExternalEvent
  alias Wik.Repo

  test "create space modal closes on successful submit", %{conn: conn} do
    user = generate(user())
    existing_space = generate(space(author: user))
    add_membership(existing_space, user, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(user)
      |> live(~p"/")

    refute has_element?(view, testid("create-space-dialog"))

    view
    |> element(testid("create-space-start"))
    |> render_click()

    assert has_element?(view, testid("create-space-dialog"))

    view
    |> form(testid("create-space-dialog") <> " form",
      form: %{"name" => "fresh-space", "description" => "A new space"}
    )
    |> render_submit()

    refute has_element?(view, testid("create-space-dialog"))
    assert render(view) =~ "fresh-space"

    assert {:ok, spaces} = Accounts.list_spaces(actor: user)
    assert Enum.any?(spaces, &(&1.name == "fresh-space" and &1.slug == "fresh-space"))
  end

  test "lists the user's aggregate feed events on the home page", %{conn: conn} do
    owner = generate(user())
    relay_owner = generate(user())
    member = generate(user())
    first_space = generate(space(author: owner))
    second_space = generate(space(author: relay_owner))

    add_membership(first_space, owner, :owner)
    add_membership(second_space, relay_owner, :owner)
    add_membership(first_space, member, :member)
    add_membership(second_space, member, :member)
    add_membership(first_space, relay_owner, :admin)
    grant_active_telegram_access(first_space, member)
    grant_active_telegram_access(second_space, member)
    grant_active_telegram_access(first_space, relay_owner)

    {:ok, _first_event} =
      Ash.create(
        Event,
        event_attrs(title: "Shared dinner"),
        action: :create,
        scope: scope(owner, first_space)
      )

    {:ok, second_event} =
      Ash.create(
        Event,
        event_attrs(
          title: "Relay event",
          relay_policy: :admins_only_spaces,
          starts_on: future_date_string(31),
          ends_on: future_date_string(31)
        ),
        action: :create,
        scope: scope(relay_owner, second_space)
      )

    {:ok, _relay_publication} =
      Events.relay_to_space(second_event, first_space,
        scope: scope(relay_owner, second_space),
        relay_note: "Worth sharing"
      )

    {:ok, view, _html} =
      conn
      |> log_in(member)
      |> live(~p"/")

    assert has_element?(view, "[data-testid='events-timeline']")
    assert has_element?(view, "[data-testid='events-year-#{future_date(30).year}']")
    assert has_element?(view, "[data-testid^='home-event-source-internal:']", first_space.name)
    assert has_element?(view, "[data-testid^='home-event-source-internal:']", second_space.name)
    assert render(view) =~ "Shared dinner"
    assert render(view) =~ "Relay event"
  end

  test "lists external events with interest using their original schedule", %{conn: conn} do
    owner = generate(user())
    member = generate(user())
    space = generate(space(author: owner))

    add_membership(space, owner, :owner)
    add_membership(space, member, :member)
    grant_active_telegram_access(space, member)

    external_event = external_event_fixture(space, owner)

    assert {:ok, participation} =
             Events.record_external_interest(
               external_event,
               %{interest: 7, extra_info: "joining later"},
               scope: scope(member, space)
             )

    {:ok, view, _html} =
      conn
      |> log_in(member)
      |> live(~p"/")

    assert has_element?(view, "[data-testid='events-timeline']")
    assert render(view) =~ "External dinner"
    assert render(view) =~ "18:00"

    assert has_element?(
             view,
             "[data-testid='home-event-source-external:#{external_event.id}']",
             space.name
           )

    assert has_element?(view, "[data-testid='timeline-event-participation-#{participation.id}']")

    assert has_element?(
             view,
             "[data-testid='timeline-event-participation-interest-#{participation.id}']"
           )

    assert has_element?(view, "a[href='/#{space.slug}/events?ext=#{external_event.id}']")
  end

  test "ignores unscheduled legacy event publications on the home page", %{conn: conn} do
    owner = generate(user())
    member = generate(user())
    space = generate(space(author: owner))

    add_membership(space, owner, :owner)
    add_membership(space, member, :member)

    event =
      Repo.insert!(%Event{
        id: Ash.UUIDv7.generate(),
        all_day: false,
        author_id: owner.id,
        description: nil,
        location: nil,
        relay_policy: :internal_only,
        space_id: space.id,
        starts_at: nil,
        status: :published,
        title: nil,
        tz: nil
      })

    Repo.insert!(%EventPublication{
      id: Ash.UUIDv7.generate(),
      event_id: event.id,
      publication_type: :origin,
      published_by_id: owner.id,
      target_space_id: space.id
    })

    {:ok, view, _html} =
      conn
      |> log_in(member)
      |> live(~p"/")

    assert has_element?(view, "[data-testid='events-timeline']")
  end

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false
    )
  end

  defp event_attrs(overrides) do
    %{
      all_day: false,
      description: "An event description",
      ends_at_time: "20:00",
      ends_on: future_date_string(30),
      location: "Community Hall, 123 Example Street",
      relay_policy: :internal_only,
      starts_at_time: "18:00",
      starts_on: future_date_string(30),
      tz: "Etc/UTC",
      title: "Shared Dinner"
    }
    |> Map.merge(Enum.into(overrides, %{}))
  end

  defp external_event_fixture(space, owner) do
    {:ok, subscription} =
      ExternalCalendarSubscription.create(
        %{ics_url: "https://calendar.example.test/community.ics"},
        scope: scope(owner, space)
      )

    Repo.insert!(%ExternalEvent{
      id: Ash.UUIDv7.generate(),
      all_day: false,
      calendar_name: "Community calendar",
      description: "Imported from an external calendar",
      ends_at: future_datetime(30, ~T[20:00:00]),
      event_url: nil,
      external_occurrence_key: "single",
      external_recurrence_id: nil,
      external_uid: "external-dinner",
      last_seen_at: DateTime.utc_now(),
      location: "Riverside Hall",
      space_id: space.id,
      starts_at: future_datetime(30, ~T[18:00:00]),
      status: :published,
      subscription_id: subscription.id,
      title: "External dinner",
      tz: "Etc/UTC"
    })
  end

  defp scope(actor, tenant) do
    %Wik.Scope{actor: actor, tenant: tenant}
  end

  defp future_datetime(offset, time) do
    offset
    |> future_date()
    |> DateTime.new!(%{time | microsecond: {0, 6}}, "Etc/UTC")
  end

  defp log_in(conn, user) do
    {:ok, token, _claims} = Jwt.token_for_user(user)
    user = Ash.Resource.set_metadata(user, %{token: token})

    conn
    |> init_test_session(%{})
    |> AuthHelpers.store_in_session(user)
  end
end
