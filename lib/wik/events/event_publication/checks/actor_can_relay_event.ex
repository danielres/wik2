defmodule Wik.Events.EventPublication.Checks.ActorCanRelayEvent do
  use Ash.Policy.SimpleCheck

  alias Wik.Accounts
  alias Wik.Accounts.Space.Access
  alias Wik.Events.Event
  alias Wik.Repo

  @impl true
  def describe(_opts), do: "actor can relay the event into the current tenant space"

  @impl true
  def match?(nil, _context, _opts), do: {:ok, false}

  def match?(actor, %{changeset: %Ash.Changeset{} = changeset, subject: subject} = context, _opts) do
    target_space_id =
      Ash.Changeset.get_attribute(changeset, :target_space_id) || tenant_space_id(context)

    event_id = Ash.Changeset.get_attribute(changeset, :event_id)

    with {:ok, target_space_id} <- present(target_space_id),
         {:ok, event_id} <- present(event_id),
         {:ok, %Event{} = event} <- load_event(subject, event_id),
         {:ok, true} <- Access.actor_can_access_space?(actor.id, target_space_id) do
      relay_allowed_by_event_policy?(actor.id, event, target_space_id)
    else
      {:ok, false} -> {:ok, false}
      {:ok, nil} -> {:ok, false}
      {:error, error} -> {:error, error}
      _ -> {:ok, false}
    end
  end

  def match?(_actor, _context, _opts), do: {:ok, false}

  def relay_allowed_by_event_policy?(_actor_id, %{status: status}, _target_space_id)
      when status != :published do
    {:ok, false}
  end

  def relay_allowed_by_event_policy?(_actor_id, %{space_id: space_id}, target_space_id)
      when space_id == target_space_id do
    {:ok, false}
  end

  def relay_allowed_by_event_policy?(
        actor_id,
        %{space_id: space_id, relay_policy: relay_policy},
        _target_space_id
      ) do
    case relay_policy do
      :internal_only ->
        {:ok, false}

      :admins_only_spaces ->
        Access.actor_can_manage_space?(actor_id, space_id)

      :members_to_spaces ->
        Access.actor_can_access_space?(actor_id, space_id)
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

  defp tenant_space_id(context) do
    with {:ok, tenant} <- Ash.Scope.ToOpts.get_tenant(context) do
      Accounts.tenant_to_space_id(tenant)
    else
      _ -> nil
    end
  end
end
