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
    user = generate(user(email: "ada@example.com"))

    html =
      render_component(&User.avatar/1, %{
        avatar_url: "https://telegram.example/avatar.png",
        link?: true,
        profile_path: "/cool-stuff/wiki/members/ada",
        user: user
      })

    assert html =~ ~s(href="/cool-stuff/wiki/members/ada")
    assert html =~ ~s(src="https://telegram.example/avatar.png")
  end

  test "avatar initials prefer the provided username" do
    html =
      render_component(&User.avatar/1, %{
        tenant: generate(group()),
        username: "danirez",
        user: generate(user(email: "zz@example.com"))
      })

    assert html =~ ">DA<"
    refute html =~ ">ZZ<"
  end

  test "avatar resolves tenant-scoped fields from membership" do
    user = generate(user(email: "zz@example.com"))

    html =
      render_component(&User.avatar/1, %{
        membership: %{
          avatar_url: "https://telegram.example/membership.png",
          user: user,
          username: "danirez"
        },
        tenant: generate(group())
      })

    assert html =~ ~s(src="https://telegram.example/membership.png")
    refute html =~ "hero-user"
  end

  test "avatar derives the profile path from membership and tenant when linking" do
    group = generate(group())
    user = generate(user(email: "ada@example.com"))

    html =
      render_component(&User.avatar/1, %{
        link?: true,
        membership: %{
          avatar_url: "https://telegram.example/avatar.png",
          user: user,
          username: "ada"
        },
        tenant: group
      })

    assert html =~ ~s(href="/#{group.slug}/wiki/members/ada")
  end
end
