defmodule Wik.Accounts.Space.Checks.ActorHasAdminSpaceMembership do
  use Ash.Policy.SimpleCheck

  require Ash.Query

  alias Wik.Accounts.Membership

  @impl true
  def describe(_opts), do: "actor is an admin of at least one space"

  @impl true
  def match?(nil, _context, _opts), do: {:ok, false}

  def match?(actor, _context, _opts) do
    query =
      Membership
      |> Ash.Query.filter(user_id == ^actor.id and type == :admin)

    Ash.exists(query, authorize?: false)
  end
end
