defmodule Wik.Events.EventPublication.Checks.ActorCanRelayEvent do
  use Ash.Policy.SimpleCheck

  alias Wik.Accounts
  alias Wik.Accounts.Group.Access
  alias Wik.Events.Event
  alias Wik.Repo

  @impl true
  def describe(_opts), do: "actor can relay the event into the current tenant group"

  @impl true
  def match?(nil, _context, _opts), do: {:ok, false}

  def match?(actor, %{changeset: %Ash.Changeset{} = changeset, subject: subject} = context, _opts) do
    target_group_id =
      Ash.Changeset.get_attribute(changeset, :target_group_id) || tenant_group_id(context)

    event_id = Ash.Changeset.get_attribute(changeset, :event_id)

    with {:ok, target_group_id} <- present(target_group_id),
         {:ok, event_id} <- present(event_id),
         {:ok, %Event{} = event} <- load_event(subject, event_id),
         {:ok, true} <- Access.actor_can_access_group?(actor.id, target_group_id) do
      actor_can_relay_event?(actor.id, event, target_group_id)
    else
      {:ok, false} -> {:ok, false}
      {:ok, nil} -> {:ok, false}
      {:error, error} -> {:error, error}
      _ -> {:ok, false}
    end
  end

  def match?(_actor, _context, _opts), do: {:ok, false}

  defp actor_can_relay_event?(_actor_id, %{status: status}, _target_group_id)
       when status != :published do
    {:ok, false}
  end

  defp actor_can_relay_event?(_actor_id, %{group_id: group_id}, target_group_id)
       when group_id == target_group_id do
    {:ok, false}
  end

  defp actor_can_relay_event?(
         actor_id,
         %{group_id: group_id, relay_policy: relay_policy},
         _target_group_id
       ) do
    case relay_policy do
      :internal_only ->
        {:ok, false}

      :admins_only_groups ->
        Access.actor_can_manage_group?(actor_id, group_id)

      :members_to_groups ->
        Access.actor_can_access_group?(actor_id, group_id)
    end
  end

  defp load_event(%Ash.Changeset{relationships: %{event: %{data: %Event{} = event}}}, _event_id),
    do: {:ok, event}

  defp load_event(_, event_id) do
    case Repo.get(Event, event_id) do
      %Event{} = event -> {:ok, event}
      nil -> {:ok, nil}
    end
  end

  defp present(nil), do: {:ok, nil}
  defp present(value), do: {:ok, value}

  defp tenant_group_id(context) do
    with {:ok, tenant} <- Ash.Scope.ToOpts.get_tenant(context) do
      Accounts.tenant_to_group_id(tenant)
    else
      _ -> nil
    end
  end
end
