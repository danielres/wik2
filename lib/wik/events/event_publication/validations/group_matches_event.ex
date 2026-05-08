defmodule Wik.Events.EventPublication.Validations.GroupMatchesEvent do
  use Ash.Resource.Validation

  alias Wik.Accounts
  alias Wik.Events.Event
  alias Wik.Repo

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, context) do
    action_name = changeset.action.name
    event_id = Ash.Changeset.get_attribute(changeset, :event_id)

    target_group_id =
      Ash.Changeset.get_attribute(changeset, :target_group_id) || tenant_group_id(context)

    with {:ok, %Event{} = event} <- load_event(event_id) do
      validate_target_group(action_name, target_group_id, event.group_id)
    else
      {:ok, nil} ->
        {:error, fields: [:event_id], message: "must reference an existing event"}

      {:error, error} ->
        {:error, error}
    end
  end

  defp validate_target_group(:publish_to_origin_group, target_group_id, event_group_id)
       when target_group_id == event_group_id do
    :ok
  end

  defp validate_target_group(:publish_to_origin_group, _target_group_id, _event_group_id) do
    {:error,
     fields: [:event_id], message: "origin publication must target the event's origin group"}
  end

  defp validate_target_group(:relay_to_group, target_group_id, event_group_id)
       when target_group_id != event_group_id do
    :ok
  end

  defp validate_target_group(:relay_to_group, _target_group_id, _event_group_id) do
    {:error, fields: [:event_id], message: "relay publication must target a different group"}
  end

  defp validate_target_group(_, _target_group_id, _event_group_id), do: :ok

  defp load_event(event_id) do
    case Repo.get(Event, event_id) do
      %Event{} = event -> {:ok, event}
      nil -> {:ok, nil}
    end
  end

  defp tenant_group_id(context) do
    with {:ok, tenant} <- Ash.Scope.ToOpts.get_tenant(context) do
      Accounts.tenant_to_group_id(tenant)
    else
      _ -> nil
    end
  end
end
