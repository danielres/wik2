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
  alias Qblog.Blocks.Types
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

  defdelegate block_to_form_params(block), to: Types
  defdelegate block_to_form_params(block, params), to: Types
  defdelegate types_available(), to: Types, as: :available
  defdelegate update_block(block, params, opts), to: Types

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
    scope = opts |> Keyword.fetch!(:scope)
    ash_opts = opts |> Keyword.put(:action, :create)
    attachable_attrs = %{attachable_id: page.id, attachable_type: "page"}

    with {:ok, order_key} <- scope |> get_next_order_key(attachable_attrs) do
      attachable_attrs
      |> Map.put(:block_id, block_id)
      |> Map.put(:order_key, order_key)
      |> then(&Ash.create(BlockPlacement, &1, ash_opts))
    end
  end

  def destroy_placed_block(placement, opts) do
    scope = Keyword.fetch!(opts, :scope)
    opts = opts |> Keyword.put(:return_notifications?, true)

    case Repo.transaction(fn ->
           with {:ok, block} <- Block.get_by_id(placement.block_id, scope: scope),
                {:ok, placement_notifications} <-
                  placement |> Ash.destroy(opts |> Keyword.put(:action, :destroy)),
                {:ok, block_notifications} <-
                  block |> Ash.destroy(opts |> Keyword.put(:action, :destroy)) do
             placement_notifications ++ block_notifications
           else
             {:error, error} -> Repo.rollback(error)
           end
         end) do
      {:ok, notifications} ->
        Ash.Notifier.notify(notifications)
        :ok

      {:error, error} ->
        {:error, error}
    end
  end

  def move_placed_block_down(placement, opts) do
    scope = Keyword.fetch!(opts, :scope)

    case get_next_placement(placement, scope) do
      nil ->
        {:ok, placement}

      next_placement ->
        order_key =
          case get_next_placement(next_placement, scope) do
            nil ->
              next_placement.order_key |> LexSortKey.key_after()

            after_next_placement ->
              LexSortKey.between(next_placement.order_key, after_next_placement.order_key)
          end

        update_placed_block_order_key(placement, order_key, scope)
    end
  end

  def move_placed_block_up(placement, opts) do
    scope = Keyword.fetch!(opts, :scope)

    case get_prev_placement(placement, scope) do
      nil ->
        {:ok, placement}

      prev_placement ->
        order_key =
          case get_prev_placement(prev_placement, scope) do
            nil ->
              prev_placement.order_key |> LexSortKey.key_before()

            before_prev_placement ->
              LexSortKey.between(
                before_prev_placement.order_key,
                prev_placement.order_key
              )
          end

        update_placed_block_order_key(placement, order_key, scope)
    end
  end

  def toggle_placed_block_width(placement, opts) do
    width =
      case placement.width do
        "half" -> "full"
        _ -> "half"
      end

    placement
    |> Ash.update(
      %{width: width},
      action: :update_width,
      scope: Keyword.fetch!(opts, :scope)
    )
  end

  # Internal  ==================================================================

  def create_group_owned_block(%{id: group_id}, block_attrs, opts) do
    _scope = Keyword.fetch!(opts, :scope)
    ash_opts = opts |> Keyword.put(:action, :create)

    block_attrs
    |> Map.delete(:owner_user_id)
    |> Map.put(:owner_group_id, group_id)
    |> then(&Ash.create(Block, &1, ash_opts))
  end

  def create_user_owned_block(block_attrs, opts) do
    scope = Keyword.fetch!(opts, :scope)
    ash_opts = opts |> Keyword.put(:action, :create)

    block_attrs
    |> Map.delete(:owner_group_id)
    |> Map.put(:owner_user_id, scope.actor.id)
    |> then(&Ash.create(Block, &1, ash_opts))
  end

  defp get_next_order_key(scope, attachable_attrs) do
    case get_last_placement(attachable_attrs, scope) do
      nil -> {:ok, LexSortKey.first()}
      placement -> LexSortKey.key_after(placement.order_key)
    end
  end

  defp get_last_placement(%{attachable_id: id, attachable_type: type}, scope) do
    BlockPlacement
    |> Ash.Query.filter(attachable_id == ^id and attachable_type == ^type)
    |> Query.sort(order_key: :desc)
    |> Query.limit(1)
    |> Ash.read!(scope: scope)
    |> List.first()
  end

  defp get_next_placement(placement, scope) do
    BlockPlacement
    |> Ash.Query.filter(
      attachable_id == ^placement.attachable_id and
        attachable_type == ^placement.attachable_type and
        order_key > ^placement.order_key
    )
    |> Query.sort(order_key: :asc)
    |> Query.limit(1)
    |> Ash.read!(scope: scope)
    |> List.first()
  end

  defp get_prev_placement(placement, scope) do
    BlockPlacement
    |> Ash.Query.filter(
      attachable_id == ^placement.attachable_id and
        attachable_type == ^placement.attachable_type and
        order_key < ^placement.order_key
    )
    |> Query.sort(order_key: :desc)
    |> Query.limit(1)
    |> Ash.read!(scope: scope)
    |> List.first()
  end

  defp update_placed_block_order_key(placement, {:ok, order_key}, scope) do
    placement
    |> Ash.update(
      %{order_key: order_key},
      action: :update_order,
      scope: scope
    )
  end

  defp update_placed_block_order_key(_placement, {:error, error}, _scope) do
    {:error, error}
  end
end
