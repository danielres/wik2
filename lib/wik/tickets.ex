defmodule Wik.Tickets do
  use Ash.Domain,
    otp_app: :wik,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  alias Wik.Tickets.Ticket
  require Ash.Query

  admin do
    show? true
  end

  resources do
    resource Ticket do
      define :get_ticket, action: :read, get_by: [:id]
    end
  end

  def tickets_query_for_user(%Wik.Accounts.User{id: user_id}) do
    Ticket
    |> Ash.Query.filter(submitted_by_id == ^user_id)
    |> Ash.Query.sort(inserted_at: :desc)
  end
end
