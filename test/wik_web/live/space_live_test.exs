defmodule WikWeb.SpaceLiveTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
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

    assert has_element?(view, "a[href='/#{space.slug}/wiki']", "1")
    assert has_element?(view, "a[href='/#{space.slug}/members']", "2")
    assert has_element?(view, "a[href='/#{space.slug}/topics']", "1")
    assert has_element?(view, "a[href='/#{space.slug}/events']", "1")
  end

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false
    )
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
