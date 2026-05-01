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
  alias Qblog.Blocks.MarkdownHistory
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
    resource Qblog.Blocks.BlockVersion
  end

  defdelegate block_to_form_params(block, params, page_tree), to: Types
  defdelegate default_data(type), to: Types
  defdelegate list_markdown_versions(block, opts), to: MarkdownHistory, as: :list_versions
  defdelegate types_available(), to: Types, as: :available
  defdelegate markdown_version_text(version, opts), to: MarkdownHistory, as: :version_text

  def create_group_owned_block_on_page(%{} = group, %Page{} = page, block_attrs, opts) do
    position = Keyword.get(opts, :position, :bottom)

    transaction_opts =
      opts
      |> Keyword.delete(:position)
      |> Keyword.put(:return_notifications?, true)

    case Repo.transaction(fn ->
           with {:ok, block, block_notifications} <-
                  create_group_owned_block_in_transaction(
                    group,
                    group.id,
                    block_attrs,
                    transaction_opts
                  ),
                {:ok, _placement, placement_notifications} <-
                  place_block_on_page(block, page, position, transaction_opts) do
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

  def create_group_owned_block(%{id: group_id} = group, block_attrs, opts) do
    transaction_opts = opts |> Keyword.put(:return_notifications?, true)

    case Repo.transaction(fn ->
           case create_group_owned_block_in_transaction(
                  group,
                  group_id,
                  block_attrs,
                  transaction_opts
                ) do
             {:ok, block, notifications} -> {block, notifications}
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

  def create_user_owned_block(block_attrs, opts) do
    transaction_opts = opts |> Keyword.put(:return_notifications?, true)

    case Repo.transaction(fn ->
           case create_user_owned_block_in_transaction(block_attrs, transaction_opts) do
             {:ok, block, notifications} -> {block, notifications}
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
    position = Keyword.get(opts, :position, :bottom)

    transaction_opts =
      opts
      |> Keyword.delete(:position)
      |> Keyword.put(:return_notifications?, true)

    case Repo.transaction(fn ->
           with {:ok, block, block_notifications} <-
                  create_user_owned_block_in_transaction(block_attrs, transaction_opts),
                {:ok, _placement, placement_notifications} <-
                  place_block_on_page(block, page, position, transaction_opts) do
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
    place_block_on_page(%{id: block_id}, page, :bottom, opts)
  end

  def place_block_on_page(%{id: block_id}, %Page{} = page, position, opts) do
    scope = opts |> Keyword.fetch!(:scope)
    ash_opts = opts |> Keyword.delete(:position) |> Keyword.put(:action, :create)
    attachable_attrs = %{attachable_id: page.id, attachable_type: "page"}

    with {:ok, order_key} <- get_placement_order_key(position, scope, attachable_attrs) do
      attachable_attrs
      |> Map.put(:block_id, block_id)
      |> Map.put(:order_key, order_key)
      |> then(&Ash.create(BlockPlacement, &1, ash_opts))
    end
  end

  def place_group_owned_block_on_page(%{id: group_id}, block_id, %Page{} = page, opts) do
    position = Keyword.get(opts, :position, :bottom)
    opts = Keyword.delete(opts, :position)
    scope = Keyword.fetch!(opts, :scope)

    Block
    |> Query.filter(id == ^block_id and owner_group_id == ^group_id)
    |> Ash.read_one(scope: scope)
    |> case do
      {:ok, nil} -> {:error, :not_found}
      {:ok, block} -> place_block_on_page_once(block, page, position, opts)
      {:error, error} -> {:error, error}
    end
  end

  defp place_block_on_page_once(%{id: block_id} = block, %Page{} = page, position, opts) do
    scope = Keyword.fetch!(opts, :scope)

    BlockPlacement
    |> Query.filter(
      attachable_id == ^page.id and attachable_type == "page" and block_id == ^block_id
    )
    |> Ash.exists?(scope: scope)
    |> case do
      true -> {:error, :already_placed}
      false -> place_block_on_page(block, page, position, opts)
    end
  end

  def list_orphan_group_owned_blocks(%{id: group_id}, opts) do
    scope = Keyword.fetch!(opts, :scope)

    Block
    |> Ash.Query.filter(owner_group_id == ^group_id)
    |> Ash.read!(scope: scope, load: [:placements])
    |> Enum.filter(&Enum.empty?(&1.placements))
  end

  def destroy_orphan_group_owned_block(group, block_id, opts) do
    scope = Keyword.fetch!(opts, :scope)
    opts = opts |> Keyword.put(:return_notifications?, true)

    group
    |> list_orphan_group_owned_blocks(scope: scope)
    |> Enum.find(&(&1.id == block_id))
    |> case do
      nil ->
        {:error, :not_found}

      block ->
        case block |> Ash.destroy(opts |> Keyword.put(:action, :destroy)) do
          {:ok, notifications} ->
            Ash.Notifier.notify(notifications)
            :ok

          {:error, error} ->
            {:error, error}
        end
    end
  end

  def destroy_placed_block(placement, opts) do
    opts = opts |> Keyword.put(:return_notifications?, true)

    case placement |> Ash.destroy(opts |> Keyword.put(:action, :destroy)) do
      {:ok, notifications} ->
        Ash.Notifier.notify(notifications)
        :ok

      {:error, error} ->
        {:error, error}
    end
  end

  def move_placed_block_down(placement, opts) do
    scope = Keyword.fetch!(opts, :scope)

    case get_next_placement_in_area(placement, scope) do
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

    case get_prev_placement_in_area(placement, scope) do
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

  def toggle_placed_block_aside(placement, opts) do
    area =
      case placement.area do
        :aside -> nil
        _ -> :aside
      end

    placement
    |> Ash.update(
      %{area: area},
      action: :update_area,
      scope: Keyword.fetch!(opts, :scope)
    )
  end

  def update_block(block, params, opts) do
    case block.type do
      :markdown ->
        MarkdownHistory.update_block(block, params, opts)

      _ ->
        Types.update_block(block, params, opts)
    end
  end

  # Internal  ==================================================================

  defp create_group_owned_block_in_transaction(_group, group_id, block_attrs, opts) do
    scope = Keyword.fetch!(opts, :scope)
    ash_opts = opts |> Keyword.put(:action, :create)
    default_data = block_attrs.type |> default_data()

    attrs =
      block_attrs
      |> Map.put_new(:data, default_data)
      |> Map.delete(:owner_user_id)
      |> Map.put(:owner_group_id, group_id)

    case Ash.create(Block, attrs, ash_opts) do
      {:ok, block, notifications} ->
        case MarkdownHistory.create_initial_version(block, scope: scope) do
          :ok -> {:ok, block, notifications}
          {:error, error} -> {:error, error}
        end

      {:ok, block} ->
        case MarkdownHistory.create_initial_version(block, scope: scope) do
          :ok -> {:ok, block, []}
          {:error, error} -> {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp create_user_owned_block_in_transaction(block_attrs, opts) do
    scope = Keyword.fetch!(opts, :scope)
    ash_opts = opts |> Keyword.put(:action, :create)
    default_data = block_attrs.type |> default_data()

    attrs =
      block_attrs
      |> Map.put_new(:data, default_data)
      |> Map.delete(:owner_group_id)
      |> Map.put(:owner_user_id, scope.actor.id)

    case Ash.create(Block, attrs, ash_opts) do
      {:ok, block, notifications} ->
        case MarkdownHistory.create_initial_version(block, scope: scope) do
          :ok -> {:ok, block, notifications}
          {:error, error} -> {:error, error}
        end

      {:ok, block} ->
        case MarkdownHistory.create_initial_version(block, scope: scope) do
          :ok -> {:ok, block, []}
          {:error, error} -> {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_placement_order_key(:top, scope, attachable_attrs) do
    scope |> get_prev_order_key(attachable_attrs)
  end

  defp get_placement_order_key(:bottom, scope, attachable_attrs) do
    scope |> get_next_order_key(attachable_attrs)
  end

  defp get_prev_order_key(scope, attachable_attrs) do
    case get_first_placement(attachable_attrs, scope) do
      nil -> {:ok, LexSortKey.first()}
      placement -> LexSortKey.key_before(placement.order_key)
    end
  end

  defp get_next_order_key(scope, attachable_attrs) do
    case get_last_placement(attachable_attrs, scope) do
      nil -> {:ok, LexSortKey.first()}
      placement -> LexSortKey.key_after(placement.order_key)
    end
  end

  defp get_first_placement(%{attachable_id: id, attachable_type: type}, scope) do
    BlockPlacement
    |> Ash.Query.filter(attachable_id == ^id and attachable_type == ^type)
    |> Query.sort(order_key: :asc)
    |> Query.limit(1)
    |> Ash.read!(scope: scope)
    |> List.first()
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

  defp get_next_placement_in_area(placement, scope) do
    BlockPlacement
    |> Ash.Query.filter(
      attachable_id == ^placement.attachable_id and
        attachable_type == ^placement.attachable_type and
        order_key > ^placement.order_key
    )
    |> filter_placements_by_area(placement.area)
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

  defp get_prev_placement_in_area(placement, scope) do
    BlockPlacement
    |> Ash.Query.filter(
      attachable_id == ^placement.attachable_id and
        attachable_type == ^placement.attachable_type and
        order_key < ^placement.order_key
    )
    |> filter_placements_by_area(placement.area)
    |> Query.sort(order_key: :desc)
    |> Query.limit(1)
    |> Ash.read!(scope: scope)
    |> List.first()
  end

  defp filter_placements_by_area(query, nil), do: Ash.Query.filter(query, is_nil(area))
  defp filter_placements_by_area(query, area), do: Ash.Query.filter(query, area == ^area)

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
