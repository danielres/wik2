defmodule Qblog.Accounts.Group.Checks.ActorCanManageCurrentTenantGroup do
  use Ash.Policy.SimpleCheck

  require Ash.Query

  alias Qblog.Accounts
  alias Qblog.Accounts.GroupUserRelation

  @impl true
  def describe(_opts), do: "actor can manage the current tenant group"

  @impl true
  def match?(nil, _context, _opts), do: {:ok, false}

  def match?(actor, context, _opts) do
    {:ok, tenant} = Ash.Scope.ToOpts.get_tenant(context)
    group_id = Accounts.tenant_to_group_id(tenant)

    query =
      GroupUserRelation
      |> Ash.Query.filter(
        user_id == ^actor.id and group_id == ^group_id and type in [:owner, :admin]
      )

    Ash.exists(query, authorize?: false)
  end
end
