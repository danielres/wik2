# TODO: add tests

defmodule Qblog.Blocs do
  use Ash.Domain,
    otp_app: :qblog,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  alias Ash.Query
  alias LexSortKey
  alias Qblog.Blocs.Block
  alias Qblog.Blocs.BlockPlacement
  alias Qblog.Repo

  require Ash.Query

  admin do
    show? true
  end

  resources do
    resource Qblog.Blocs.Block
    resource Qblog.Blocs.BlockPlacement
  end

  # TODO: extract all below 
  def add_block(parent, block_attrs, opts) do
    scope = Keyword.fetch!(opts, :scope)
    attachable_attrs = attachable_attrs(parent)

    Repo.transaction(fn ->
      with {:ok, order_key} <- next_order_key(attachable_attrs, scope),
           {:ok, block} <- Ash.create(Block, block_attrs, scope: scope),
           {:ok, placement} <-
             Ash.create(
               BlockPlacement,
               Map.merge(attachable_attrs, %{
                 block_id: block.id,
                 order_key: order_key
               }),
               scope: scope
             ) do
        %{block: block, placement: placement}
      else
        {:error, error} -> Repo.rollback(error)
      end
    end)
    |> normalize_transaction_result()
  end

  defp attachable_attrs(%{id: attachable_id} = parent) do
    %{
      attachable_id: attachable_id,
      attachable_type: attachable_type(parent)
    }
  end

  defp attachable_type(parent) do
    parent.__struct__
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  defp next_order_key(attachable_attrs, scope) do
    case last_placement(attachable_attrs, scope) do
      nil -> {:ok, LexSortKey.first()}
      placement -> LexSortKey.key_after(placement.order_key)
    end
  end

  defp last_placement(%{attachable_id: attachable_id, attachable_type: attachable_type}, scope) do
    BlockPlacement
    |> Query.filter(attachable_id: attachable_id, attachable_type: attachable_type)
    |> Query.sort(order_key: :desc)
    |> Query.limit(1)
    |> Ash.read!(scope: scope)
    |> List.first()
  end

  defp normalize_transaction_result({:ok, result}), do: {:ok, result}
  defp normalize_transaction_result({:error, error}), do: {:error, error}
end
