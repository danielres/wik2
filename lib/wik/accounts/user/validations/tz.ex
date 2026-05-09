defmodule Wik.Accounts.User.Validations.Tz do
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    tz = Ash.Changeset.get_attribute(changeset, :tz)

    cond do
      is_nil(tz) ->
        :ok

      Utils.Tz.valid?(tz) ->
        :ok

      true ->
        {:error, fields: [:tz], message: "must be a valid IANA timezone"}
    end
  end
end
