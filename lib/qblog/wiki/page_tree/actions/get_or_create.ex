defmodule Qblog.Wiki.PageTree.Actions.GetOrCreate do
  use Ash.Resource.Actions.Implementation

  alias Qblog.Wiki.PageTree

  def run(_input, _opts, context) do
    opts = ash_opts(context)

    case PageTree
         |> Ash.Query.for_read(:read)
         |> Ash.read_one(opts) do
      {:ok, %PageTree{} = page_tree} ->
        {:ok, page_tree}

      {:ok, nil} ->
        PageTree.create(%{}, opts)

      {:error, error} ->
        {:error, error}
    end
  end

  defp ash_opts(context) do
    [
      actor: context.actor,
      tenant: context.tenant,
      authorize?: context.authorize?,
      domain: context.domain,
      tracer: context.tracer
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end
end
