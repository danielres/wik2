defmodule Wik.Events.EventParticipation.Checks.ActorCanManageOwnParticipation do
  use Ash.Policy.SimpleCheck

  alias Wik.Accounts
  alias Wik.Accounts.Membership
  alias Wik.Events.EventPublication
  alias Wik.Events.ExternalEvent

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
    external_event_id = Ash.Subject.get_argument_or_attribute(subject, :external_event_id)

    with {:ok, true} <- membership_belongs_to_actor?(membership_id, space_id, actor),
         {:ok, true} <-
           target_belongs_to_space?(publication_id, external_event_id, space_id, tenant) do
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

  defp target_belongs_to_space?(publication_id, nil, space_id, tenant)
       when not is_nil(publication_id) do
    publication_belongs_to_space?(publication_id, space_id, tenant)
  end

  defp target_belongs_to_space?(nil, external_event_id, space_id, tenant)
       when not is_nil(external_event_id) do
    external_event_belongs_to_space?(external_event_id, space_id, tenant)
  end

  defp target_belongs_to_space?(_publication_id, _external_event_id, _space_id, _tenant) do
    {:ok, false}
  end

  defp publication_belongs_to_space?(publication_id, space_id, tenant) do
    publication =
      EventPublication
      |> Ash.Query.filter(id == ^publication_id)
      |> Ash.read_one!(authorize?: false, domain: Wik.Events, tenant: tenant)

    {:ok, publication && publication.target_space_id == space_id}
  end

  defp external_event_belongs_to_space?(external_event_id, space_id, tenant) do
    external_event =
      ExternalEvent
      |> Ash.Query.filter(id == ^external_event_id)
      |> Ash.read_one!(authorize?: false, domain: Wik.Events, tenant: tenant)

    {:ok, external_event && external_event.space_id == space_id}
  end
end
