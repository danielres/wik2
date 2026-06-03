defmodule Wik.Events.EventParticipation.Checks.ActorCanManageOwnParticipation do
  use Ash.Policy.SimpleCheck

  alias Wik.Accounts
  alias Wik.Accounts.Membership
  alias Wik.Events.EventPublication

  require Ash.Query

  @impl true
  def describe(_opts), do: "actor manages their own event participation"

  @impl true
  def match?(nil, _context, _opts), do: {:ok, false}

  def match?(actor, %{subject: subject} = context, _opts) do
    {:ok, tenant} = Ash.Scope.ToOpts.get_tenant(context)
    space_id = Accounts.tenant_to_space_id(tenant)
    membership_id = Ash.Subject.get_argument_or_attribute(subject, :membership_id)
    publication_id = Ash.Subject.get_argument_or_attribute(subject, :publication_id)

    with {:ok, true} <- membership_belongs_to_actor?(membership_id, space_id, actor),
         {:ok, true} <- publication_belongs_to_space?(publication_id, space_id) do
      {:ok, true}
    else
      {:ok, false} -> {:ok, false}
      {:error, error} -> {:error, error}
    end
  end

  defp membership_belongs_to_actor?(membership_id, space_id, actor) do
    Membership
    |> Ash.Query.filter(space_id == ^space_id and id == ^membership_id and user_id == ^actor.id)
    |> Ash.exists(authorize?: false, domain: Accounts)
  end

  defp publication_belongs_to_space?(publication_id, space_id) do
    EventPublication
    |> Ash.Query.filter(id == ^publication_id and target_space_id == ^space_id)
    |> Ash.exists(authorize?: false, domain: Wik.Events)
  end
end
