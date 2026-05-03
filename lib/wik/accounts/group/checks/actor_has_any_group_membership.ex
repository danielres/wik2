defmodule Wik.Accounts.Group.Checks.ActorHasAnyGroupMembership do
  use Ash.Policy.SimpleCheck

  require Ash.Query

  alias Wik.Accounts.GroupUserRelation

  @impl true
  def describe(_opts), do: "actor belongs to at least one group"

  @impl true
  def match?(nil, _context, _opts), do: {:ok, false}

  def match?(actor, _context, _opts) do
    query =
      GroupUserRelation
      |> Ash.Query.filter(user_id == ^actor.id)

    Ash.exists(query, authorize?: false)
  end
end
