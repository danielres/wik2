defmodule Wik.Events.Event.Checks.ActorCanReadRelayedEvent do
  import Ecto.Query, only: [from: 2]

  use Ash.Policy.FilterCheck

  alias Wik.Accounts.Space.Checks.Access
  alias Wik.Events.EventPublication
  alias Wik.Repo

  @impl true
  def describe(_opts), do: "actor can read the event via a relay publication"

  @impl true
  def filter(nil, _context, _opts), do: false

  def filter(actor, _context, _opts) do
    accessible_space_ids = Access.accessible_space_ids(actor.id)
    readable_event_ids = relayed_event_ids(accessible_space_ids)

    Ash.Expr.expr(id in ^readable_event_ids)
  end

  defp relayed_event_ids([]), do: []

  defp relayed_event_ids(accessible_space_ids) do
    from(publication in EventPublication,
      where: publication.target_space_id in ^accessible_space_ids,
      select: publication.event_id,
      distinct: true
    )
    |> Repo.all()
  end
end
