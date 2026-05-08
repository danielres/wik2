defmodule WikWeb.HomeLiveTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Accounts
  alias Wik.Accounts.GroupUserRelation
  alias Wik.Events
  alias Wik.Events.Event

  test "create group modal closes on successful submit", %{conn: conn} do
    user = generate(user())
    existing_group = generate(group(author: user))
    add_membership(existing_group, user, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(user)
      |> live(~p"/")

    refute has_element?(view, testid("create-group-dialog"))

    view
    |> element(testid("create-group-start"))
    |> render_click()

    assert has_element?(view, testid("create-group-dialog"))

    view
    |> form(testid("create-group-dialog") <> " form",
      form: %{"name" => "fresh-group", "description" => "A new group"}
    )
    |> render_submit()

    refute has_element?(view, testid("create-group-dialog"))
    assert render(view) =~ "fresh-group"

    assert {:ok, groups} = Accounts.list_groups(actor: user)
    assert Enum.any?(groups, &(&1.name == "fresh-group"))
  end

  test "lists the user's aggregate feed events on the home page", %{conn: conn} do
    owner = generate(user())
    relay_owner = generate(user())
    member = generate(user())
    first_group = generate(group(author: owner))
    second_group = generate(group(author: relay_owner))

    add_membership(first_group, owner, :owner)
    add_membership(second_group, relay_owner, :owner)
    add_membership(first_group, member, :member)
    add_membership(second_group, member, :member)
    add_membership(first_group, relay_owner, :admin)
    grant_active_telegram_access(first_group, member)
    grant_active_telegram_access(second_group, member)
    grant_active_telegram_access(first_group, relay_owner)

    {:ok, _first_event} =
      Ash.create(
        Event,
        event_attrs(title: "Shared dinner"),
        action: :create,
        scope: scope(owner, first_group)
      )

    {:ok, second_event} =
      Ash.create(
        Event,
        event_attrs(
          title: "Relay event",
          relay_policy: :admins_only_groups,
          starts_on: "2026-05-11",
          ends_on: "2026-05-11"
        ),
        action: :create,
        scope: scope(relay_owner, second_group)
      )

    {:ok, _relay_publication} =
      Events.relay_to_group(second_event, first_group,
        scope: scope(relay_owner, second_group),
        relay_note: "Worth sharing"
      )

    {:ok, view, _html} =
      conn
      |> log_in(member)
      |> live(~p"/")

    assert has_element?(view, "[data-testid='events-timeline']")
    assert render(view) =~ "Shared dinner"
    assert render(view) =~ "Relay event"
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

  defp log_in(conn, user) do
    {:ok, token, _claims} = Jwt.token_for_user(user)
    user = Ash.Resource.set_metadata(user, %{token: token})

    conn
    |> init_test_session(%{})
    |> AuthHelpers.store_in_session(user)
  end
end
