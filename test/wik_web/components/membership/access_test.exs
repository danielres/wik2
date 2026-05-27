defmodule WikWeb.Components.Membership.AccessTest do
  use WikWeb.ConnCase, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias WikWeb.Components.Membership.Access

  test "grant_card renders profile access details with issuer fallback and telegram type label" do
    now = DateTime.utc_now()

    html =
      render_component(&Access.grant_card/1, %{
        grant: %{
          id: "grant-1",
          inserted_at: now,
          last_verified_at: now,
          status: :active,
          external_identity: %{
            avatar_url: nil,
            provider: :telegram,
            provider_user_id: "telegram-user-1",
            username: "ada"
          },
          source: %{
            provider: :telegram,
            metadata: %{"chat" => %{"type" => "group"}},
            claimed_by_user: %{email: "issuer@example.com"},
            provider_source_id: "-100123",
            space: %{memberships: []},
            title: "Hobbies"
          }
        },
        variant: :profile
      })

    assert html =~ ~s(data-testid="access-grant-grant-1")
    assert html =~ ~s(data-testid="access-grant-issuer-grant-1")
    assert html =~ ~s(data-testid="access-grant-via-grant-1")
    assert html =~ ~s(data-testid="access-grant-source-title-grant-1")
    assert html =~ ~s(data-testid="access-grant-identity-grant-1")
    assert html =~ ~s(data-testid="access-grant-status-grant-1")
    assert html =~ "Telegram group membership"
    assert html =~ "Hobbies"
    assert html =~ "id: -100123"
    assert html =~ "issuer"
    assert html =~ "@ada"
    assert html =~ "active"
  end
end
