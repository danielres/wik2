defmodule QblogWeb.Components.UserTest do
  use QblogWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Qblog.TestGenerators

  alias QblogWeb.Components.User

  test "avatar renders a generic user icon without tenant context" do
    html =
      render_component(&User.avatar/1, %{
        user: generate(user(email: nil))
      })

    assert html =~ "hero-user"
  end
end
