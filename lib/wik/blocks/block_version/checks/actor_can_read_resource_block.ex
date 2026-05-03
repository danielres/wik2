defmodule Wik.Blocks.BlockVersion.Checks.ActorCanReadResourceBlock do
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts), do: "actor can read the current resource block"

  @impl true
  def match?(nil, _context, _opts), do: {:ok, false}

  def match?(actor, %{subject: version}, _opts) do
    with {:ok, block} <- load_resource_block(version),
         true <- Ash.can?({block, :read}, actor) do
      {:ok, true}
    else
      false -> {:ok, false}
      {:error, error} -> {:error, error}
    end
  end

  defp load_resource_block(%{block: %Ash.NotLoaded{}} = version) do
    case Ash.load(version, :block, authorize?: false) do
      {:ok, %{block: block}} -> {:ok, block}
      {:error, error} -> {:error, error}
    end
  end

  defp load_resource_block(%{block: block}), do: {:ok, block}
end
