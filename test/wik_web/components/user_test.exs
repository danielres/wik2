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
        tenant: generate(space()),
        user: generate(user(email: nil))
      })

    assert html =~ "hero-user"
  end

  test "avatar renders the resolved avatar image when provided" do
    html =
      render_component(&User.avatar/1, %{
        avatar_url: "https://telegram.example/avatar.png",
        tenant: generate(space()),
        user: generate(user(email: nil))
      })

    assert html =~ ~s(src="https://telegram.example/avatar.png")
    refute html =~ "hero-user"
  end

  test "avatar renders google avatar images through the local cache" do
    html =
      render_component(&User.avatar/1, %{
        avatar_url: "https://lh3.googleusercontent.com/a/avatar=s96-c",
        tenant: generate(space()),
        user: generate(user(email: nil))
      })

    assert html =~ ~s(src="/avatars/google/)
    refute html =~ ~s(src="https://lh3.googleusercontent.com/a/avatar=s96-c")
    refute html =~ "hero-user"
  end

  test "identity links to the profile when the membership has a space" do
    user = generate(user(email: "ada@example.com"))
    space = generate(space())

    html =
      render_component(&User.identity/1, %{
        avatar_size: "sm",
        link?: true,
        membership: %{
          avatar_url: "https://telegram.example/avatar.png",
          display_name: "ada",
          space: space,
          user: user,
          username: "ada"
        }
      })

    assert html =~ ~s(href="/#{space.slug}/wiki/members/ada")
    assert html =~ ~s(src="https://telegram.example/avatar.png")
    assert html =~ "ada"
  end

  test "avatar initials prefer the provided username" do
    html =
      render_component(&User.avatar/1, %{
        tenant: generate(space()),
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
        tenant: generate(space())
      })

    assert html =~ ~s(src="https://telegram.example/membership.png")
    refute html =~ "hero-user"
  end

  test "avatar does not link when given a membership" do
    html =
      render_component(&User.avatar/1, %{
        membership: %{
          avatar_url: "https://telegram.example/avatar.png",
          username: "ada"
        }
      })

    refute html =~ "href="
  end
end
