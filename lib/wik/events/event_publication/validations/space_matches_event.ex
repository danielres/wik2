defmodule Wik.Events.EventPublication.Validations.SpaceMatchesEvent do
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

    target_space_id =
      Ash.Changeset.get_attribute(changeset, :target_space_id) || tenant_space_id(context)

    with {:ok, %Event{} = event} <- load_event(event_id) do
      validate_target_space(action_name, target_space_id, event.space_id)
    else
      {:ok, nil} ->
        {:error, fields: [:event_id], message: "must reference an existing event"}

      {:error, error} ->
        {:error, error}
    end
  end

  defp validate_target_space(:publish_to_origin_space, target_space_id, event_space_id)
       when target_space_id == event_space_id do
    :ok
  end

  defp validate_target_space(:publish_to_origin_space, _target_space_id, _event_space_id) do
    {:error,
     fields: [:event_id], message: "origin publication must target the event's origin space"}
  end

  defp validate_target_space(:relay_to_space, target_space_id, event_space_id)
       when target_space_id != event_space_id do
    :ok
  end

  defp validate_target_space(:relay_to_space, _target_space_id, _event_space_id) do
    {:error, fields: [:event_id], message: "relay publication must target a different space"}
  end

  defp validate_target_space(_, _target_space_id, _event_space_id), do: :ok

  defp load_event(event_id) do
    case Repo.get(Event, event_id) do
      %Event{} = event -> {:ok, event}
      nil -> {:ok, nil}
    end
  end

  defp tenant_space_id(context) do
    with {:ok, tenant} <- Ash.Scope.ToOpts.get_tenant(context) do
      Accounts.tenant_to_space_id(tenant)
    else
      _ -> nil
    end
  end
end
