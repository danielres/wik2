defmodule Wik.Events.EventParticipation.Validations.ExactlyOneTarget do
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    publication_id = Ash.Changeset.get_attribute(changeset, :publication_id)
    external_event_id = Ash.Changeset.get_attribute(changeset, :external_event_id)

    case {is_nil(publication_id), is_nil(external_event_id)} do
      {false, true} ->
        :ok

      {true, false} ->
        :ok

      _ ->
        {:error,
         fields: [:publication_id, :external_event_id],
         message: "must target either a publication or an external event"}
    end
  end
end
