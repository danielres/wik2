defmodule WikWeb.CalendarFeedControllerTest do
  use WikWeb.ConnCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.Membership
  alias Wik.Events
  alias Wik.Events.Event
  alias Wik.Events.Feeds.Token

  test "returns an aggregate feed for a valid token", %{conn: conn} do
    owner = generate(user())
    member = generate(user())
    space = generate(space(author: owner))

    add_membership(space, owner, :owner)
    add_membership(space, member, :member)
    grant_active_telegram_access(space, member)

    {:ok, _event} =
      Ash.create(
        Event,
        event_attrs(title: "Shared dinner"),
        action: :create,
        scope: scope(owner, space)
      )

    token = Token.issue_for_aggregate(member)
    conn = get(conn, ~p"/calendar/#{token}")

    assert response(conn, 200) =~ "BEGIN:VCALENDAR"
    assert response(conn, 200) =~ "SUMMARY:Shared dinner"
    assert response(conn, 200) =~ "Visible in: #{space.name}"
    assert get_resp_header(conn, "content-type") == ["text/calendar; charset=utf-8"]
  end

  test "aggregate feed includes relay context in the description", %{conn: conn} do
    owner = generate(user())
    relay_owner = generate(user())
    member = generate(user())
    origin_space = generate(space(author: owner))
    target_space = generate(space(author: relay_owner))

    add_membership(origin_space, owner, :owner)
    add_membership(origin_space, member, :member)
    add_membership(target_space, owner, :owner)
    add_membership(target_space, member, :member)
    grant_active_telegram_access(origin_space, member)
    grant_active_telegram_access(target_space, member)

    {:ok, event} =
      Ash.create(
        Event,
        event_attrs(relay_policy: :admins_only_spaces, title: "Shared dinner"),
        action: :create,
        scope: scope(owner, origin_space)
      )

    {:ok, _publication} =
      Events.relay_to_space(event, target_space,
        relay_note: "Worth sharing",
        action: :create,
        scope: scope(owner, origin_space)
      )

    token = Token.issue_for_aggregate(member)
    conn = get(conn, ~p"/calendar/#{token}")

    assert response(conn, 200) =~ "Visible in: #{origin_space.name}"
    assert response(conn, 200) =~ "Visible in: #{target_space.name}"
    assert response(conn, 200) =~ "Relay note: Worth sharing"
  end

  test "returns a space feed for a valid token", %{conn: conn} do
    owner = generate(user())
    member = generate(user())
    space = generate(space(author: owner))

    add_membership(space, owner, :owner)
    add_membership(space, member, :member)
    grant_active_telegram_access(space, member)

    {:ok, _event} =
      Ash.create(
        Event,
        event_attrs(title: "Shared dinner"),
        action: :create,
        scope: scope(owner, space)
      )

    token = Token.issue_for_space(member, space)
    conn = get(conn, ~p"/calendar/#{token}")

    assert response(conn, 200) =~ "BEGIN:VCALENDAR"
    assert response(conn, 200) =~ "SUMMARY:Shared dinner"
  end

  test "returns not found for an invalid token", %{conn: conn} do
    conn = get(conn, ~p"/calendar/invalid-token")

    assert response(conn, 404) == "Not found"
  end

  test "returns not found for a revoked token", %{conn: conn} do
    member = generate(user())
    token = Token.issue_for_aggregate(member)

    assert :ok = Token.revoke_for_aggregate(member)

    conn = get(conn, ~p"/calendar/#{token}")

    assert response(conn, 404) == "Not found"
  end

  test "space feed stops working after space access is lost", %{conn: conn} do
    owner = generate(user())
    member = generate(user())
    space = generate(space(author: owner))

    add_membership(space, owner, :owner)
    add_membership(space, member, :member)
    %{grant: grant} = grant_active_telegram_access(space, member)

    {:ok, _event} =
      Ash.create(
        Event,
        event_attrs(title: "Shared dinner"),
        action: :create,
        scope: scope(owner, space)
      )

    token = Token.issue_for_space(member, space)

    Ash.update!(grant, %{status: :inactive},
      action: :update,
      authorize?: false
    )

    conn = get(conn, ~p"/calendar/#{token}")

    assert response(conn, 404) == "Not found"
  end

  test "aggregate feed drops a space's events after space access is lost", %{conn: conn} do
    owner = generate(user())
    member = generate(user())
    space = generate(space(author: owner))

    add_membership(space, owner, :owner)
    add_membership(space, member, :member)
    %{grant: grant} = grant_active_telegram_access(space, member)

    {:ok, _event} =
      Ash.create(
        Event,
        event_attrs(title: "Shared dinner"),
        action: :create,
        scope: scope(owner, space)
      )

    token = Token.issue_for_aggregate(member)

    Ash.update!(grant, %{status: :inactive},
      action: :update,
      authorize?: false
    )

    conn = get(conn, ~p"/calendar/#{token}")

    assert response(conn, 200) =~ "BEGIN:VCALENDAR"
    refute response(conn, 200) =~ "SUMMARY:Shared dinner"
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
      ends_on: "2026-05-10",
      location: "Community Hall, 123 Example Street",
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
end
