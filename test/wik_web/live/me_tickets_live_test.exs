defmodule WikWeb.MeTicketsLiveTest do
  use WikWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Tickets.Ticket

  test "user can submit a ticket and see it in my tickets", %{conn: conn} do
    user = generate(user())

    {:ok, view, _html} =
      conn
      |> log_in(user)
      |> live(~p"/me/tickets/new")

    assert has_element?(view, "#new-ticket-form")

    view
    |> form("#new-ticket-form",
      form: %{
        "body" => "I would like an export of my data.",
        "subject" => "Privacy export",
        "type" => "privacy_request"
      }
    )
    |> render_submit()

    assert_redirect(view, ~p"/me/tickets")

    {:ok, list_view, _html} =
      conn
      |> log_in(user)
      |> live(~p"/me/tickets")

    assert render(list_view) =~ "Privacy export"
    assert render(list_view) =~ "Privacy"
    assert render(list_view) =~ "New"
  end

  test "my tickets only shows the current user's tickets", %{conn: conn} do
    user = generate(user())
    other_user = generate(user())

    create_ticket(user, %{subject: "My ticket"})
    create_ticket(other_user, %{subject: "Other ticket"})

    {:ok, view, _html} =
      conn
      |> log_in(user)
      |> live(~p"/me/tickets")

    assert render(view) =~ "My ticket"
    refute render(view) =~ "Other ticket"
  end

  test "anonymous users are redirected from ticket pages", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/me/tickets")
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/me/tickets/new")
  end

  defp create_ticket(user, attrs) do
    Ash.create!(
      Ticket,
      %{
        app_path: "/me/tickets/new",
        body: Map.get(attrs, :body, "Ticket body"),
        subject: Map.get(attrs, :subject, "Ticket subject"),
        type: Map.get(attrs, :type, :feedback)
      },
      action: :submit,
      actor: user,
      domain: Wik.Tickets
    )
  end

  defp log_in(conn, user) do
    {:ok, token, _claims} = Jwt.token_for_user(user)
    user = Ash.Resource.set_metadata(user, %{token: token})

    conn
    |> init_test_session(%{})
    |> AuthHelpers.store_in_session(user)
  end
end
