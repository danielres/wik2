defmodule WikWeb.SpaceAdminLive.AccessSourcesTest do
  use WikWeb.ConnCase, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias WikWeb.SpaceAdminLive.AccessSources

  test "renders telegram source summary and active grant details" do
    now = DateTime.utc_now()

    groups =
      AccessSources.prepare([
        %{
          id: "source-1",
          grants: [
            %{
              id: "grant-1",
              inserted_at: now,
              last_verified_at: now,
              status: :active,
              user_id: "user-1",
              user: %{email: "ada@example.com"},
              external_identity: %{
                provider: :telegram,
                provider_user_id: "telegram-user-1",
                username: "ada"
              }
            },
            %{
              id: "grant-2",
              inserted_at: now,
              last_verified_at: now,
              status: :inactive,
              user_id: "user-2",
              user: %{email: "grace@example.com"},
              external_identity: %{
                display_name: "Grace Hopper",
                provider: :telegram,
                provider_user_id: "telegram-user-2"
              }
            }
          ],
          metadata: %{"chat" => %{"type" => "group", "title" => "Wik Group"}},
          provider: :telegram,
          space: %{
            memberships: [
              %{
                user_id: "user-1",
                username: "ada-l",
                type: :admin,
                user: %{email: "ada@example.com"}
              },
              %{
                user_id: "user-2",
                username: nil,
                type: :member,
                user: %{email: "grace@example.com"}
              }
            ]
          },
          status: :active,
          title: "Wik Group"
        }
      ])

    html = render_component(&AccessSources.render/1, %{groups: groups})

    assert html =~ "Telegram group"
    assert html =~ "Group"
    assert html =~ "Wik Group"
    assert html =~ "ada-l (admin)"
    assert html =~ "@ada"
    assert html =~ ~s(data-testid="access-source-grant-grant-1")
    refute html =~ "grace (member)"
    refute html =~ "Grace Hopper"
    refute html =~ ~s(data-testid="access-source-grant-grant-2")
  end
end
