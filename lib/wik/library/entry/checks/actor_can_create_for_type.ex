defmodule Wik.Library.Entry.Checks.ActorCanCreateForType do
  use Ash.Policy.SimpleCheck

  alias Ash.Query
  alias Wik.Accounts
  alias Wik.Accounts.Space.Checks.Access
  alias Wik.Library.EntryType

  require Ash.Query

  @impl true
  def describe(_opts), do: "actor may create entries for the selected Library type"

  @impl true
  def match?(nil, _context, _opts), do: {:ok, false}

  def match?(actor, %{subject: subject} = context, _opts) do
    {:ok, tenant} = Ash.Scope.ToOpts.get_tenant(context)
    space_id = Accounts.tenant_to_space_id(tenant)
    type_id = Ash.Subject.get_argument_or_attribute(subject, :type_id)

    type =
      EntryType
      |> Query.filter(id == ^type_id and space_id == ^space_id)
      |> Ash.read_one!(authorize?: false, domain: Wik.Library, tenant: tenant)

    case type do
      %{entry_creation_permission: :members} -> {:ok, true}
      %{entry_creation_permission: :admins} -> Access.actor_can_manage_space?(actor.id, space_id)
      _missing -> {:ok, false}
    end
  end
end
