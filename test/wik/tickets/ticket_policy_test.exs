defmodule Wik.Tickets.TicketPolicyTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Tickets
  alias Wik.Tickets.Ticket

  test "authenticated user can submit a ticket" do
    user = generate(user())

    assert {:ok, ticket} =
             Tickets.submit_ticket(
               %{
                 app_path: "/me/tickets/new",
                 body: "Please delete my data.",
                 subject: "Privacy request",
                 type: :privacy_request
               },
               user
             )

    assert ticket.submitted_by_id == user.id
    assert ticket.status == :new
  end

  test "user can read their own ticket but not another user's ticket" do
    user = generate(user())
    other_user = generate(user())

    ticket =
      Ash.create!(
        Ticket,
        %{
          app_path: "/me/tickets/new",
          body: "Please delete my data.",
          subject: "Privacy request",
          type: :privacy_request
        },
        action: :submit,
        actor: user,
        domain: Wik.Tickets
      )

    assert {:ok, %{id: ticket_id}} = Tickets.get_ticket_for_user(ticket.id, user)
    assert ticket_id == ticket.id
    assert {:error, _error} = Tickets.get_ticket_for_user(ticket.id, other_user)
  end

  test "superadmin can triage any ticket" do
    user = generate(user())
    superadmin = generate(user(role: :superadmin))

    ticket =
      Ash.create!(
        Ticket,
        %{
          app_path: "/me/tickets/new",
          body: "Something needs review.",
          subject: "Moderation issue",
          type: :moderation_report
        },
        action: :submit,
        actor: user,
        domain: Wik.Tickets
      )

    assert {:ok, updated_ticket} =
             Tickets.triage_ticket(
               ticket,
               %{
                 admin_notes: "Handled",
                 handled_at: DateTime.utc_now(),
                 handled_by_id: superadmin.id,
                 status: :closed
               },
               superadmin
             )

    assert updated_ticket.status == :closed
    assert updated_ticket.handled_by_id == superadmin.id
  end
end
