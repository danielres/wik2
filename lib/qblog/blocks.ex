defmodule Qblog.Blocks do
  use Ash.Domain,
    otp_app: :qblog,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  alias Ash.Query
  alias LexSortKey
  alias Qblog.Blocks.Block
  alias Qblog.Blocks.BlockPlacement
  alias Qblog.Repo
  alias Qblog.Wiki.Page

  require Ash.Query

  admin do
    show? true
  end

  resources do
    resource Qblog.Blocks.Block
    resource Qblog.Blocks.BlockPlacement
  end

  def create_group_owned_block(%{id: group_id}, block_attrs, opts) do
    _scope = Keyword.fetch!(opts, :scope)
    ash_opts = opts |> Keyword.put(:action, :create)

    block_attrs
    |> Map.delete(:owner_user_id)
    |> Map.put(:owner_group_id, group_id)
    |> then(&Ash.create(Block, &1, ash_opts))
  end

  def create_group_owned_block_on_page(%{} = group, %Page{} = page, block_attrs, opts) do
    transaction_opts = opts |> Keyword.put(:return_notifications?, true)

    case Repo.transaction(fn ->
           with {:ok, block, block_notifications} <-
                  create_group_owned_block(group, block_attrs, transaction_opts),
                {:ok, _placement, placement_notifications} <-
                  place_block_on_page(block, page, transaction_opts) do
             {block, block_notifications ++ placement_notifications}
           else
             {:error, error} -> Repo.rollback(error)
           end
         end) do
      {:ok, {block, notifications}} ->
        Ash.Notifier.notify(notifications)
        {:ok, block}

      {:error, error} ->
        {:error, error}
    end
  end

  def update_block_text(block, text, opts) do
    _scope = Keyword.fetch!(opts, :scope)

    block
    |> Ash.update(%{data: %{text: text}}, opts |> Keyword.put(:action, :update))
  end

  def create_user_owned_block(block_attrs, opts) do
    scope = Keyword.fetch!(opts, :scope)
    ash_opts = opts |> Keyword.put(:action, :create)

    block_attrs
    |> Map.delete(:owner_group_id)
    |> Map.put(:owner_user_id, scope.actor.id)
    |> then(&Ash.create(Block, &1, ash_opts))
  end

  def create_user_owned_block_on_page(%Page{} = page, block_attrs, opts) do
    transaction_opts = opts |> Keyword.put(:return_notifications?, true)

    case Repo.transaction(fn ->
           with {:ok, block, block_notifications} <-
                  create_user_owned_block(block_attrs, transaction_opts),
                {:ok, _placement, placement_notifications} <-
                  place_block_on_page(block, page, transaction_opts) do
             {block, block_notifications ++ placement_notifications}
           else
             {:error, error} -> Repo.rollback(error)
           end
         end) do
      {:ok, {block, notifications}} ->
        Ash.Notifier.notify(notifications)
        {:ok, block}

      {:error, error} ->
        {:error, error}
    end
  end

  def place_block_on_page(%{id: block_id}, %Page{} = page, opts) do
    scope = Keyword.fetch!(opts, :scope)
    ash_opts = opts |> Keyword.put(:action, :create)
    attachable_attrs = page_attachable_attrs(page)

    with {:ok, order_key} <- next_order_key(attachable_attrs, scope) do
      attachable_attrs
      |> Map.put(:block_id, block_id)
      |> Map.put(:order_key, order_key)
      |> then(&Ash.create(BlockPlacement, &1, ash_opts))
    end
  end

  defp page_attachable_attrs(%Page{id: page_id}) do
    %{
      attachable_id: page_id,
      attachable_type: "page"
    }
  end

  defp next_order_key(attachable_attrs, scope) do
    case last_placement(attachable_attrs, scope) do
      nil -> {:ok, LexSortKey.first()}
      placement -> LexSortKey.key_after(placement.order_key)
    end
  end

  defp last_placement(%{attachable_id: attachable_id, attachable_type: attachable_type}, scope) do
    BlockPlacement
    |> Ash.Query.filter(attachable_id == ^attachable_id and attachable_type == ^attachable_type)
    |> Query.sort(order_key: :desc)
    |> Query.limit(1)
    |> Ash.read!(scope: scope)
    |> List.first()
  end
end
