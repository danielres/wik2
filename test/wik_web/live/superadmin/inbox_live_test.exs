defmodule WikWeb.Superadmin.InboxLiveTest do
  use WikWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Tickets.Ticket

  test "superadmin can see and update ticket admin state", %{conn: conn} do
    superadmin = generate(user(role: :superadmin))
    user = generate(user())

    ticket =
      Ash.create!(
        Ticket,
        %{
          app_path: "/me/tickets/new",
          body: "Please review this.",
          subject: "Moderation issue",
          type: :moderation_report
        },
        action: :submit,
        actor: user,
        domain: Wik.Tickets
      )

    {:ok, view, _html} =
      conn
      |> log_in(superadmin)
      |> live(~p"/_/inbox")

    assert has_element?(view, testid("inbox-ticket-#{ticket.id}"))

    render_click(element(view, testid("inbox-ticket-#{ticket.id}")))

    assert has_element?(view, testid("inbox-ticket-dialog"))

    view
    |> form("#inbox-ticket-update-form",
      form: %{
        "admin_notes" => "Handled manually",
        "status" => "closed"
      }
    )
    |> render_submit()

    assert render(view) =~ "Ticket updated"
    assert render(view) =~ "Closed"
  end

  test "normal users cannot see the inbox", %{conn: conn} do
    user = generate(user())

    assert {:error, {:redirect, %{to: "/"}}} =
             conn
             |> log_in(user)
             |> live(~p"/_/inbox")
  end

  defp log_in(conn, user) do
    {:ok, token, _claims} = Jwt.token_for_user(user)
    user = Ash.Resource.set_metadata(user, %{token: token})

    conn
    |> init_test_session(%{})
    |> AuthHelpers.store_in_session(user)
  end
end
