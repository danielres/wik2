defmodule Qblog.Blocks.Block.Validations.DataMatchesType do
  use Ash.Resource.Validation

  alias Qblog.Blocks.Types

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    type = changeset |> Ash.Changeset.get_attribute(:type)
    data = changeset |> Ash.Changeset.get_attribute(:data)

    type |> Types.validate_data(data)
  end
end
