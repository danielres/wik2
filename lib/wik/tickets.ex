defmodule Wik.Tickets do
  use Ash.Domain,
    otp_app: :wik,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  alias Wik.Accounts.User
  alias Wik.Tickets.Ticket

  require Ash.Query

  admin do
    show? true
  end

  resources do
    resource Ticket
  end

  def submit_ticket(attrs, %User{} = actor) do
    Ash.create(
      Ticket,
      attrs,
      action: :submit,
      actor: actor,
      domain: __MODULE__
    )
  end

  def list_tickets_for_user(%User{id: user_id} = actor) do
    Ticket
    |> Ash.Query.filter(submitted_by_id == ^user_id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read(
      actor: actor,
      domain: __MODULE__,
      load: [:handled_by]
    )
  end

  def get_ticket_for_user(id, %User{} = actor) when is_binary(id) do
    Ash.get(Ticket, id,
      actor: actor,
      domain: __MODULE__,
      load: [:handled_by]
    )
  end

  def list_tickets_for_superadmin(%User{} = actor) do
    Ticket
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read(
      actor: actor,
      domain: __MODULE__,
      load: [:submitted_by, :handled_by]
    )
  end

  def get_ticket_for_superadmin(id, %User{} = actor) when is_binary(id) do
    Ash.get(Ticket, id,
      actor: actor,
      domain: __MODULE__,
      load: [:submitted_by, :handled_by]
    )
  end

  def triage_ticket(%Ticket{} = ticket, attrs, %User{} = actor) do
    {handled_by_id, attrs} =
      Map.pop(attrs, :handled_by_id, Map.get(attrs, "handled_by_id"))

    attrs = Map.delete(attrs, "handled_by_id")

    ticket
    |> Ash.Changeset.for_update(:triage, attrs, actor: actor)
    |> maybe_manage_handled_by(handled_by_id)
    |> Ash.update(actor: actor, domain: __MODULE__)
  end

  defp maybe_manage_handled_by(changeset, nil) do
    Ash.Changeset.manage_relationship(changeset, :handled_by, nil,
      type: :append_and_remove,
      authorize?: false
    )
  end

  defp maybe_manage_handled_by(changeset, handled_by_id)
       when is_binary(handled_by_id) do
    case Ash.get(User, handled_by_id, authorize?: false, domain: Wik.Accounts) do
      {:ok, handled_by} ->
        Ash.Changeset.manage_relationship(changeset, :handled_by, handled_by,
          type: :append_and_remove,
          authorize?: false
        )

      {:error, _error} ->
        changeset
    end
  end
end
