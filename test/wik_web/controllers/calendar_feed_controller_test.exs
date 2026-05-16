defmodule WikWeb.CalendarFeedControllerTest do
  use WikWeb.ConnCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.GroupUserRelation
  alias Wik.Events
  alias Wik.Events.Event
  alias Wik.Events.Feeds.Token

  test "returns an aggregate feed for a valid token", %{conn: conn} do
    owner = generate(user())
    member = generate(user())
    group = generate(group(author: owner))

    add_membership(group, owner, :owner)
    add_membership(group, member, :member)
    grant_active_telegram_access(group, member)

    {:ok, _event} =
      Ash.create(
        Event,
        event_attrs(title: "Shared dinner"),
        action: :create,
        scope: scope(owner, group)
      )

    token = Token.issue_for_aggregate(member)
    conn = get(conn, ~p"/calendar/#{token}")

    assert response(conn, 200) =~ "BEGIN:VCALENDAR"
    assert response(conn, 200) =~ "SUMMARY:Shared dinner"
    assert response(conn, 200) =~ "Visible in: #{group.name}"
    assert response(conn, 200) =~ "From: #{group.name}"
    assert get_resp_header(conn, "content-type") == ["text/calendar; charset=utf-8"]
  end

  test "aggregate feed includes relay context in the description", %{conn: conn} do
    owner = generate(user())
    relay_owner = generate(user())
    member = generate(user())
    origin_group = generate(group(author: owner))
    target_group = generate(group(author: relay_owner))

    add_membership(origin_group, owner, :owner)
    add_membership(origin_group, member, :member)
    add_membership(target_group, owner, :owner)
    add_membership(target_group, member, :member)
    grant_active_telegram_access(origin_group, member)
    grant_active_telegram_access(target_group, member)

    {:ok, event} =
      Ash.create(
        Event,
        event_attrs(relay_policy: :admins_only_groups, title: "Shared dinner"),
        action: :create,
        scope: scope(owner, origin_group)
      )

    {:ok, _publication} =
      Events.relay_to_group(event, target_group,
        relay_note: "Worth sharing",
        action: :create,
        scope: scope(owner, origin_group)
      )

    token = Token.issue_for_aggregate(member)
    conn = get(conn, ~p"/calendar/#{token}")

    assert response(conn, 200) =~ "Visible in: #{origin_group.name}"
    assert response(conn, 200) =~ "Visible in: #{target_group.name}"
    assert response(conn, 200) =~ "From: #{origin_group.name}"
    assert response(conn, 200) =~ "Relayed by: #{owner}"
    assert response(conn, 200) =~ "Relay note: Worth sharing"
  end

  test "returns a group feed for a valid token", %{conn: conn} do
    owner = generate(user())
    member = generate(user())
    group = generate(group(author: owner))

    add_membership(group, owner, :owner)
    add_membership(group, member, :member)
    grant_active_telegram_access(group, member)

    {:ok, _event} =
      Ash.create(
        Event,
        event_attrs(title: "Shared dinner"),
        action: :create,
        scope: scope(owner, group)
      )

    token = Token.issue_for_group(member, group)
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

  test "group feed stops working after group access is lost", %{conn: conn} do
    owner = generate(user())
    member = generate(user())
    group = generate(group(author: owner))

    add_membership(group, owner, :owner)
    add_membership(group, member, :member)
    %{grant: grant} = grant_active_telegram_access(group, member)

    {:ok, _event} =
      Ash.create(
        Event,
        event_attrs(title: "Shared dinner"),
        action: :create,
        scope: scope(owner, group)
      )

    token = Token.issue_for_group(member, group)

    Ash.update!(grant, %{status: :inactive},
      action: :update,
      authorize?: false
    )

    conn = get(conn, ~p"/calendar/#{token}")

    assert response(conn, 404) == "Not found"
  end

  test "aggregate feed drops a group's events after group access is lost", %{conn: conn} do
    owner = generate(user())
    member = generate(user())
    group = generate(group(author: owner))

    add_membership(group, owner, :owner)
    add_membership(group, member, :member)
    %{grant: grant} = grant_active_telegram_access(group, member)

    {:ok, _event} =
      Ash.create(
        Event,
        event_attrs(title: "Shared dinner"),
        action: :create,
        scope: scope(owner, group)
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

  defp add_membership(group, user, type) do
    Ash.create!(
      GroupUserRelation,
      %{group_id: group.id, type: type, user_id: user.id},
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
end
