defmodule Wik.Events.Event.Validations.Tz do
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    tz = Ash.Changeset.get_attribute(changeset, :tz)

    if Utils.Tz.valid?(tz) do
      :ok
    else
      {:error, fields: [:tz], message: "must be a valid IANA timezone"}
    end
  end
end
