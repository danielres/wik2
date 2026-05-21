defmodule WikWeb.Components.PresencesTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest, only: [render_component: 2]
  import Wik.TestGenerators

  alias WikWeb.Components.Presences

  test "avatars renders without membership data" do
    user = generate(user())
    group = generate(group(author: user))

    html =
      render_component(&Presences.avatars/1, %{
        presences: [
          %{
            id: user.id,
            metas: [],
            user: user
          }
        ],
        tenant: group
      })

    assert html =~ ~s(id="online-user-#{user.id}")
    refute html =~ ~s(href="/#{group.slug}/wiki/members/)
  end
end
