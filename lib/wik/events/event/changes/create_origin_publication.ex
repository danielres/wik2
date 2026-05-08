defmodule Wik.Events.Event.Changes.CreateOriginPublication do
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Wik.Events.EventPublication

  @impl true
  def change(changeset, _opts, context) do
    Changeset.after_action(changeset, fn _changeset, event ->
      case EventPublication.publish_to_origin_group(
             %{event_id: event.id},
             scope: context
           ) do
        {:ok, _publication} ->
          {:ok, event}

        {:error, error} ->
          {:error, error}
      end
    end)
  end
end
