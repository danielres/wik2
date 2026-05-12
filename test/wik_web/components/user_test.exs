defmodule WikWeb.Components.UserTest do
  use WikWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias WikWeb.Components.User

  test "avatar renders a generic user icon without tenant context" do
    html =
      render_component(&User.avatar/1, %{
        user: generate(user(email: nil))
      })

    assert html =~ "hero-user"
  end

  test "avatar renders a generic user icon with tenant context when initials are blank" do
    html =
      render_component(&User.avatar/1, %{
        tenant: generate(group()),
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

  test "avatar image links to the profile when link and tenant are provided" do
    tenant = generate(group(name: "cool-stuff"))
    user = generate(user(email: "ada@example.com"))

    html =
      render_component(&User.avatar/1, %{
        avatar_url: "https://telegram.example/avatar.png",
        link?: true,
        tenant: tenant,
        user: user
      })

    assert html =~ ~s(href="/cool-stuff/wiki/members/ada")
    assert html =~ ~s(src="https://telegram.example/avatar.png")
  end
end
