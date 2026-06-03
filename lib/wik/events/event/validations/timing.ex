defmodule Wik.Events.Event.Validations.Timing do
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    all_day = Ash.Changeset.get_attribute(changeset, :all_day)
    ends_at = Ash.Changeset.get_attribute(changeset, :ends_at)
    source_external_event_id = Ash.Changeset.get_attribute(changeset, :source_external_event_id)
    starts_at = Ash.Changeset.get_attribute(changeset, :starts_at)

    cond do
      not is_nil(source_external_event_id) ->
        :ok

      not all_day && is_nil(ends_at) ->
        {:error, fields: [:ends_at], message: "must be present"}

      all_day ->
        :ok

      is_nil(starts_at) or is_nil(ends_at) ->
        :ok

      DateTime.compare(ends_at, starts_at) != :gt ->
        {:error, fields: [:ends_at], message: "must be after the start time"}

      true ->
        :ok
    end
  end
end
