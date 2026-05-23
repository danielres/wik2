defmodule Wik.Accounts.Profile.Checks.ActorCanReadProfile do
  import Ecto.Query, only: [from: 2]

  use Ash.Policy.FilterCheck

  alias Wik.Accounts.Space.Checks.Access
  alias Wik.Repo

  require Ash.Expr

  @impl true
  def describe(_opts), do: "actor can read profiles from accessible spaces"

  @impl true
  def filter(nil, _context, _opts), do: false

  def filter(actor, _context, _opts) do
    Ash.Expr.expr(membership_id in ^accessible_membership_ids(actor.id))
  end

  defp accessible_membership_ids(actor_id) do
    space_ids = Access.accessible_space_ids(actor_id)

    from(membership in "memberships",
      where: membership.space_id in type(^space_ids, {:array, Ecto.UUID}),
      select: membership.id
    )
    |> Repo.all()
  end
end
