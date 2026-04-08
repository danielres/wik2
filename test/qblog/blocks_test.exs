defmodule Qblog.BlocksTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Blocks
  alias Qblog.Blocks.Block
  alias Qblog.Blocks.BlockPlacement
  alias Qblog.Scope
  alias Qblog.Wiki.Page

  require Ash.Query

  describe "create_user_owned_block/2" do
    test "sets author and user owner and clears group owner" do
      actor = generate(user())
      group = generate(group())

      assert {:ok, block} =
               Blocks.create_user_owned_block(
                 %{
                   data: %{"text" => "Hello"},
                   owner_group_id: group.id,
                   type: :text
                 },
                 scope: scope(actor)
               )

      assert block.author_id == actor.id
      assert block.owner_group_id == nil
      assert block.owner_user_id == actor.id
    end
  end

  describe "create_group_owned_block/3" do
    test "sets author and group owner and clears user owner" do
      actor = generate(user())
      group = generate(group(author: actor))

      assert {:ok, block} =
               Blocks.create_group_owned_block(
                 group,
                 %{
                   data: %{"text" => "Hello"},
                   owner_user_id: actor.id,
                   type: :text
                 },
                 scope: scope(actor)
               )

      assert block.author_id == actor.id
      assert block.owner_group_id == group.id
      assert block.owner_user_id == nil
    end
  end

  describe "create_user_owned_block_on_page/3" do
    test "creates a user-owned block and places it on the page" do
      actor = generate(user())
      group = generate(group(author: actor))
      scope = scope(actor, group)
      {:ok, page} = Page.create(scope: scope)

      assert {:ok, block} =
               Blocks.create_user_owned_block_on_page(
                 page,
                 %{data: %{"text" => "Hello"}, type: :text},
                 scope: scope
               )

      placement =
        BlockPlacement
        |> Ash.Query.filter(
          attachable_id == ^page.id and attachable_type == "page" and block_id == ^block.id
        )
        |> Ash.read_one!(scope: scope)

      assert block.author_id == actor.id
      assert block.owner_user_id == actor.id
      assert block.owner_group_id == nil
      assert placement.block_id == block.id
    end
  end

  describe "create_group_owned_block_on_page/4" do
    test "creates a group-owned block and places it on the page" do
      actor = generate(user())
      group = generate(group(author: actor))
      scope = scope(actor, group)
      {:ok, page} = Page.create(scope: scope)

      assert {:ok, block} =
               Blocks.create_group_owned_block_on_page(
                 group,
                 page,
                 %{data: %{"text" => "Hello"}, type: :text},
                 scope: scope
               )

      placement =
        BlockPlacement
        |> Ash.Query.filter(
          attachable_id == ^page.id and attachable_type == "page" and block_id == ^block.id
        )
        |> Ash.read_one!(scope: scope)

      assert block.author_id == actor.id
      assert block.owner_group_id == group.id
      assert block.owner_user_id == nil
      assert placement.block_id == block.id
    end
  end

  describe "place_block_on_page/3" do
    test "creates a placement for the parent" do
      actor = generate(user())
      group = generate(group(author: actor))
      scope = scope(actor, group)
      {:ok, page} = Page.create(scope: scope)

      {:ok, block} =
        Blocks.create_user_owned_block(%{data: %{"text" => "Hello"}, type: :text}, scope: scope)

      assert {:ok, placement} = Blocks.place_block_on_page(block, page, scope: scope)

      assert placement.attachable_id == page.id
      assert placement.attachable_type == "page"
      assert placement.block_id == block.id
      assert is_binary(placement.order_key)
    end

    test "assigns later order keys after earlier placements" do
      actor = generate(user())
      group = generate(group(author: actor))
      scope = scope(actor, group)
      {:ok, page} = Page.create(scope: scope)

      {:ok, block1} =
        Blocks.create_user_owned_block(%{data: %{"text" => "First"}, type: :text}, scope: scope)

      {:ok, block2} =
        Blocks.create_user_owned_block(%{data: %{"text" => "Second"}, type: :text}, scope: scope)

      assert {:ok, placement1} = Blocks.place_block_on_page(block1, page, scope: scope)
      assert {:ok, placement2} = Blocks.place_block_on_page(block2, page, scope: scope)

      assert placement1.order_key < placement2.order_key
    end
  end

  describe "move_placed_block_down/2" do
    test "moves a placement after the next placement" do
      actor = generate(user())
      group = generate(group(author: actor))
      scope = scope(actor, group)
      {:ok, page} = Page.create(scope: scope)

      {:ok, block1} =
        Blocks.create_user_owned_block(%{data: %{"text" => "First"}, type: :text}, scope: scope)

      {:ok, block2} =
        Blocks.create_user_owned_block(%{data: %{"text" => "Second"}, type: :text}, scope: scope)

      {:ok, placement1} = Blocks.place_block_on_page(block1, page, scope: scope)
      {:ok, placement2} = Blocks.place_block_on_page(block2, page, scope: scope)

      assert {:ok, moved_placement} = Blocks.move_placed_block_down(placement1, scope: scope)
      assert moved_placement.order_key > placement2.order_key
    end
  end

  describe "move_placed_block_up/2" do
    test "moves a placement before the previous placement" do
      actor = generate(user())
      group = generate(group(author: actor))
      scope = scope(actor, group)
      {:ok, page} = Page.create(scope: scope)

      {:ok, block1} =
        Blocks.create_user_owned_block(%{data: %{"text" => "First"}, type: :text}, scope: scope)

      {:ok, block2} =
        Blocks.create_user_owned_block(%{data: %{"text" => "Second"}, type: :text}, scope: scope)

      {:ok, placement1} = Blocks.place_block_on_page(block1, page, scope: scope)
      {:ok, placement2} = Blocks.place_block_on_page(block2, page, scope: scope)

      assert {:ok, moved_placement} = Blocks.move_placed_block_up(placement2, scope: scope)
      assert moved_placement.order_key < placement1.order_key
    end
  end

  describe "destroy_placed_block/2" do
    test "removes the placement and the block" do
      actor = generate(user())
      group = generate(group(author: actor))
      scope = scope(actor, group)
      {:ok, page} = Page.create(scope: scope)

      {:ok, block} =
        Blocks.create_group_owned_block_on_page(
          group,
          page,
          %{data: %{"text" => "Hello"}, type: :text},
          scope: scope
        )

      placement =
        BlockPlacement
        |> Ash.Query.filter(
          attachable_id == ^page.id and attachable_type == "page" and block_id == ^block.id
        )
        |> Ash.read_one!(scope: scope)

      assert :ok = Blocks.destroy_placed_block(placement, scope: scope)

      placement =
        BlockPlacement
        |> Ash.Query.filter(
          attachable_id == ^page.id and attachable_type == "page" and block_id == ^block.id
        )
        |> Ash.read_one!(scope: scope)

      block =
        Block
        |> Ash.Query.filter(id == ^block.id)
        |> Ash.read_one!(scope: scope)

      assert placement == nil
      assert block == nil
    end
  end

  defp scope(actor, tenant \\ nil) do
    %Scope{actor: actor, tenant: tenant}
  end
end
