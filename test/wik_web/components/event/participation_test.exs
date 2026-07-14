defmodule WikWeb.Components.Event.ParticipationTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias WikWeb.Components.Event.Panels.Participation

  test "other member participations link to member profiles while current participation edits interest" do
    html =
      render_component(&Participation.render/1, %{
        current_member_participation:
          participation("participation-current", "membership-current"),
        current_membership: membership("membership-current", "current"),
        participations: [
          participation("participation-other", "membership-other", "ada"),
          participation("participation-current", "membership-current", "current")
        ],
        scope: %{tenant: %{slug: "berlin-dancers"}},
        source_id: "event-1",
        source_type: "internal",
        testid_prefix: "event"
      })

    document = LazyHTML.from_fragment(html)

    assert document
           |> LazyHTML.query(
             ~s(button[data-testid="event-participation-participation-current"][phx-click="event_interest_start"])
           )
           |> Enum.any?()

    refute document
           |> LazyHTML.query(~s(a[data-testid="event-participation-participation-current"]))
           |> Enum.any?()

    assert document
           |> LazyHTML.query(
             ~s(a[data-testid="event-participation-participation-other"][href="/berlin-dancers/wiki/members/ada"])
           )
           |> Enum.any?()

    assert html =~
             ~r/data-testid="event-participation-participation-current".*data-testid="event-participation-participation-other"/s
  end

  defp participation(id, membership_id, username \\ "current") do
    %{
      id: id,
      extra_info: nil,
      interest: 7,
      membership: membership(membership_id, username),
      membership_id: membership_id
    }
  end

  defp membership(id, username) do
    %{
      id: id,
      avatar_url: nil,
      display_name: username,
      user: nil,
      username: username
    }
  end
end
