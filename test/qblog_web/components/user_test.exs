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

  test "avatar renders the resolved avatar image when provided" do
    html =
      render_component(&User.avatar/1, %{
        avatar_url: "https://telegram.example/avatar.png",
        tenant: generate(group()),
        user: generate(user(email: nil))
      })

    assert html =~ ~s(src="https://telegram.example/avatar.png")
    refute html =~ "hero-user"
  end
end
