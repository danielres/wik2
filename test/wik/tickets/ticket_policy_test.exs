defmodule Wik.Tickets.TicketPolicyTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators
  alias Wik.Tickets.Ticket

  test "authenticated user can submit a ticket" do
    user = generate(user())

    assert {:ok, ticket} =
             Ash.create(
               Ticket,
               %{
                 app_path: "/me/tickets/new",
                 body: "Please delete my data.",
                 subject: "Privacy request",
                 type: :privacy_request
               },
               action: :submit,
               actor: user
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

    assert {:ok, %{id: ticket_id}} = Ash.get(Ticket, ticket.id, actor: user)
    assert ticket_id == ticket.id
    assert {:error, _error} = Ash.get(Ticket, ticket.id, actor: other_user)
  end

  test "superadmin can update ticket admin state" do
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
             Ash.update(
               ticket,
               %{
                 admin_notes: "Handled",
                 handled_at: DateTime.utc_now(),
                 status: :closed
               },
               action: :update,
               actor: superadmin
             )

    assert updated_ticket.status == :closed
  end

  test "superadmin can update ticket notes after changing status" do
    user = generate(user())
    superadmin = generate(user(role: :superadmin))

    ticket =
      Ash.create!(
        Ticket,
        %{
          app_path: "/me/tickets/new",
          body: "Needs follow-up.",
          subject: "Feedback",
          type: :feedback
        },
        action: :submit,
        actor: user,
        domain: Wik.Tickets
      )

    {:ok, in_progress_ticket} =
      Ash.update(
        ticket,
        %{
          status: :in_progress
        },
        action: :update,
        actor: superadmin
      )

    assert {:ok, updated_ticket} =
             Ash.update(
               in_progress_ticket,
               %{
                 admin_notes: "Still investigating"
               },
               action: :update,
               actor: superadmin
             )

    assert updated_ticket.status == :in_progress
    assert updated_ticket.admin_notes == "Still investigating"
  end
end
