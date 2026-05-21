defmodule Wik.BlocksTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.Membership
  alias Wik.Blocks
  alias Wik.Blocks.Block
  alias Wik.Blocks.BlockPlacement
  alias Wik.Scope
  alias Wik.Wiki.Page

  require Ash.Query

  describe "create_user_owned_block/2" do
    test "sets author and user owner and clears space owner" do
      actor = generate(user())
      space = generate(space())

      assert {:ok, block} =
               Blocks.create_user_owned_block(
                 %{
                   data: %{"text" => "Hello"},
                   owner_space_id: space.id,
                   type: :text
                 },
                 scope: scope(actor)
               )

      assert block.author_id == actor.id
      assert block.owner_space_id == nil
      assert block.owner_user_id == actor.id
    end
  end

  describe "create_space_owned_block/3" do
    test "sets author and space owner and clears user owner" do
      actor = generate(user())
      space = generate(space(author: actor))
      add_membership(space, actor, :owner)

      assert {:ok, block} =
               Blocks.create_space_owned_block(
                 space,
                 %{
                   data: %{"text" => "Hello"},
                   owner_user_id: actor.id,
                   type: :text
                 },
                 scope: scope(actor, space)
               )

      assert block.author_id == actor.id
      assert block.owner_space_id == space.id
      assert block.owner_user_id == nil
    end
  end

  describe "create_user_owned_block_on_page/3" do
    test "creates a user-owned block and places it on the page" do
      actor = generate(user())
      space = generate(space(author: actor))
      add_membership(space, actor, :owner)
      scope = scope(actor, space)
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
      assert block.owner_space_id == nil
      assert placement.block_id == block.id
      assert placement.space_id == space.id
      assert placement.area == nil
    end
  end

  describe "create_space_owned_block_on_page/4" do
    test "creates a space-owned block and places it on the page" do
      actor = generate(user())
      space = generate(space(author: actor))
      add_membership(space, actor, :owner)
      scope = scope(actor, space)
      {:ok, page} = Page.create(scope: scope)

      assert {:ok, block} =
               Blocks.create_space_owned_block_on_page(
                 space,
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
      assert block.owner_space_id == space.id
      assert block.owner_user_id == nil
      assert placement.block_id == block.id
      assert placement.space_id == space.id
      assert placement.area == nil
    end

    test "can place the new block before existing placements" do
      actor = generate(user())
      space = generate(space(author: actor))
      add_membership(space, actor, :owner)
      scope = scope(actor, space)
      {:ok, page} = Page.create(scope: scope)

      assert {:ok, block1} =
               Blocks.create_space_owned_block_on_page(
                 space,
                 page,
                 %{data: %{"text" => "First"}, type: :text},
                 scope: scope
               )

      assert {:ok, block2} =
               Blocks.create_space_owned_block_on_page(
                 space,
                 page,
                 %{data: %{"text" => "Second"}, type: :text},
                 position: :top,
                 scope: scope
               )

      placement1 =
        BlockPlacement
        |> Ash.Query.filter(
          attachable_id == ^page.id and attachable_type == "page" and block_id == ^block1.id
        )
        |> Ash.read_one!(scope: scope)

      placement2 =
        BlockPlacement
        |> Ash.Query.filter(
          attachable_id == ^page.id and attachable_type == "page" and block_id == ^block2.id
        )
        |> Ash.read_one!(scope: scope)

      assert placement2.order_key < placement1.order_key
    end
  end

  describe "place_block_on_page/3" do
    test "creates a placement for the parent" do
      actor = generate(user())
      space = generate(space(author: actor))
      add_membership(space, actor, :owner)
      scope = scope(actor, space)
      {:ok, page} = Page.create(scope: scope)

      {:ok, block} =
        Blocks.create_user_owned_block(%{data: %{"text" => "Hello"}, type: :text}, scope: scope)

      assert {:ok, placement} = Blocks.place_block_on_page(block, page, scope: scope)

      assert placement.attachable_id == page.id
      assert placement.attachable_type == "page"
      assert placement.block_id == block.id
      assert placement.space_id == space.id
      assert is_binary(placement.order_key)
    end

    test "assigns later order keys after earlier placements" do
      actor = generate(user())
      space = generate(space(author: actor))
      add_membership(space, actor, :owner)
      scope = scope(actor, space)
      {:ok, page} = Page.create(scope: scope)

      {:ok, block1} =
        Blocks.create_user_owned_block(%{data: %{"text" => "First"}, type: :text}, scope: scope)

      {:ok, block2} =
        Blocks.create_user_owned_block(%{data: %{"text" => "Second"}, type: :text}, scope: scope)

      assert {:ok, placement1} = Blocks.place_block_on_page(block1, page, scope: scope)
      assert {:ok, placement2} = Blocks.place_block_on_page(block2, page, scope: scope)

      assert placement1.order_key < placement2.order_key
    end

    test "can place a block before existing placements" do
      actor = generate(user())
      space = generate(space(author: actor))
      add_membership(space, actor, :owner)
      scope = scope(actor, space)
      {:ok, page} = Page.create(scope: scope)

      {:ok, block1} =
        Blocks.create_user_owned_block(%{data: %{"text" => "First"}, type: :text}, scope: scope)

      {:ok, block2} =
        Blocks.create_user_owned_block(%{data: %{"text" => "Second"}, type: :text}, scope: scope)

      assert {:ok, placement1} = Blocks.place_block_on_page(block1, page, scope: scope)
      assert {:ok, placement2} = Blocks.place_block_on_page(block2, page, :top, scope: scope)

      assert placement2.order_key < placement1.order_key
    end
  end

  describe "move_placed_block_down/2" do
    test "moves a placement after the next placement" do
      actor = generate(user())
      space = generate(space(author: actor))
      add_membership(space, actor, :owner)
      scope = scope(actor, space)
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

    test "moves a placement only within its current area" do
      actor = generate(user())
      space = generate(space(author: actor))
      add_membership(space, actor, :owner)
      scope = scope(actor, space)
      {:ok, page} = Page.create(scope: scope)

      {:ok, block1} =
        Blocks.create_user_owned_block(%{data: %{"text" => "First"}, type: :text}, scope: scope)

      {:ok, block2} =
        Blocks.create_user_owned_block(%{data: %{"text" => "Second"}, type: :text}, scope: scope)

      {:ok, block3} =
        Blocks.create_user_owned_block(%{data: %{"text" => "Third"}, type: :text}, scope: scope)

      {:ok, placement1} = Blocks.place_block_on_page(block1, page, scope: scope)
      {:ok, placement2} = Blocks.place_block_on_page(block2, page, scope: scope)
      {:ok, placement3} = Blocks.place_block_on_page(block3, page, scope: scope)

      assert {:ok, placement2} = Blocks.toggle_placed_block_aside(placement2, scope: scope)
      assert placement2.area == :aside

      assert {:ok, moved_placement1} = Blocks.move_placed_block_down(placement1, scope: scope)
      assert moved_placement1.order_key > placement3.order_key

      assert {:ok, moved_placement2} = Blocks.move_placed_block_down(placement2, scope: scope)
      assert moved_placement2.order_key == placement2.order_key
    end
  end

  describe "move_placed_block_up/2" do
    test "moves a placement before the previous placement" do
      actor = generate(user())
      space = generate(space(author: actor))
      add_membership(space, actor, :owner)
      scope = scope(actor, space)
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

    test "moves a placement up only within its current area" do
      actor = generate(user())
      space = generate(space(author: actor))
      add_membership(space, actor, :owner)
      scope = scope(actor, space)
      {:ok, page} = Page.create(scope: scope)

      {:ok, block1} =
        Blocks.create_user_owned_block(%{data: %{"text" => "First"}, type: :text}, scope: scope)

      {:ok, block2} =
        Blocks.create_user_owned_block(%{data: %{"text" => "Second"}, type: :text}, scope: scope)

      {:ok, block3} =
        Blocks.create_user_owned_block(%{data: %{"text" => "Third"}, type: :text}, scope: scope)

      {:ok, placement1} = Blocks.place_block_on_page(block1, page, scope: scope)
      {:ok, placement2} = Blocks.place_block_on_page(block2, page, scope: scope)
      {:ok, placement3} = Blocks.place_block_on_page(block3, page, scope: scope)

      assert {:ok, placement2} = Blocks.toggle_placed_block_aside(placement2, scope: scope)
      assert {:ok, placement3} = Blocks.toggle_placed_block_aside(placement3, scope: scope)
      assert placement2.area == :aside
      assert placement3.area == :aside

      assert {:ok, moved_placement3} = Blocks.move_placed_block_up(placement3, scope: scope)
      assert moved_placement3.order_key < placement2.order_key
      assert moved_placement3.order_key > placement1.order_key
    end
  end

  describe "toggle_placed_block_aside/2" do
    test "toggles a placement between main and aside" do
      actor = generate(user())
      space = generate(space(author: actor))
      add_membership(space, actor, :owner)
      scope = scope(actor, space)
      {:ok, page} = Page.create(scope: scope)

      {:ok, block} =
        Blocks.create_user_owned_block(%{data: %{"text" => "Hello"}, type: :text}, scope: scope)

      {:ok, placement} = Blocks.place_block_on_page(block, page, scope: scope)

      assert placement.area == nil

      assert {:ok, aside_placement} =
               Blocks.toggle_placed_block_aside(placement, scope: scope)

      assert aside_placement.area == :aside

      assert {:ok, main_placement} =
               Blocks.toggle_placed_block_aside(aside_placement, scope: scope)

      assert main_placement.area == nil
    end
  end

  describe "destroy_placed_block/2" do
    test "removes the placement and keeps the block" do
      actor = generate(user())
      space = generate(space(author: actor))
      add_membership(space, actor, :owner)
      scope = scope(actor, space)
      {:ok, page} = Page.create(scope: scope)

      {:ok, block} =
        Blocks.create_space_owned_block_on_page(
          space,
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

      persisted_block =
        Block
        |> Ash.Query.filter(id == ^block.id)
        |> Ash.read_one!(scope: scope)

      assert placement == nil
      assert persisted_block.id == block.id
    end
  end

  describe "list_orphan_space_owned_blocks/2" do
    test "returns only space-owned blocks with no placements" do
      actor = generate(user())
      other_actor = generate(user())
      space = generate(space(author: actor))
      other_space = generate(space(author: other_actor))
      add_membership(space, actor, :owner)
      add_membership(other_space, other_actor, :owner)
      scope = scope(actor, space)
      {:ok, page} = Page.create(scope: scope)

      {:ok, orphan_block} =
        Blocks.create_space_owned_block(
          space,
          %{data: %{"text" => "Orphan"}, type: :text},
          scope: scope
        )

      {:ok, placed_block} =
        Blocks.create_space_owned_block_on_page(
          space,
          page,
          %{data: %{"text" => "Placed"}, type: :text},
          scope: scope
        )

      {:ok, _other_space_block} =
        Blocks.create_space_owned_block(
          other_space,
          %{data: %{"text" => "Other space"}, type: :text},
          scope: scope(other_actor, other_space)
        )

      orphan_blocks = Blocks.list_orphan_space_owned_blocks(space, scope: scope)

      assert Enum.map(orphan_blocks, & &1.id) == [orphan_block.id]
      refute Enum.any?(orphan_blocks, &(&1.id == placed_block.id))
    end
  end

  describe "place_space_owned_block_on_page/4" do
    test "places an existing space-owned block on a page" do
      actor = generate(user())
      space = generate(space(author: actor))
      add_membership(space, actor, :owner)
      scope = scope(actor, space)
      {:ok, page} = Page.create(scope: scope)

      {:ok, block} =
        Blocks.create_space_owned_block(
          space,
          %{data: %{"text" => "Reusable"}, type: :text},
          scope: scope
        )

      assert {:ok, placement} =
               Blocks.place_space_owned_block_on_page(space, block.id, page, scope: scope)

      assert placement.block_id == block.id
      assert placement.attachable_id == page.id
      assert placement.attachable_type == "page"
    end

    test "rejects blocks owned by another space" do
      actor = generate(user())
      space = generate(space(author: actor))
      other_space = generate(space(author: actor))
      add_membership(space, actor, :owner)
      add_membership(other_space, actor, :owner)
      scope = scope(actor, space)
      other_scope = scope(actor, other_space)
      {:ok, page} = Page.create(scope: scope)

      {:ok, other_block} =
        Blocks.create_space_owned_block(
          other_space,
          %{data: %{"text" => "Other"}, type: :text},
          scope: other_scope
        )

      assert {:error, :not_found} =
               Blocks.place_space_owned_block_on_page(space, other_block.id, page, scope: scope)
    end

    test "rejects a block that is already placed on the page" do
      actor = generate(user())
      space = generate(space(author: actor))
      add_membership(space, actor, :owner)
      scope = scope(actor, space)
      {:ok, page} = Page.create(scope: scope)

      {:ok, block} =
        Blocks.create_space_owned_block_on_page(
          space,
          page,
          %{data: %{"text" => "Reusable"}, type: :text},
          scope: scope
        )

      assert {:error, :already_placed} =
               Blocks.place_space_owned_block_on_page(space, block.id, page, scope: scope)
    end
  end

  describe "destroy_orphan_space_owned_block/3" do
    test "destroys a space-owned orphan block" do
      actor = generate(user())
      space = generate(space(author: actor))
      add_membership(space, actor, :owner)
      scope = scope(actor, space)

      {:ok, orphan_block} =
        Blocks.create_space_owned_block(
          space,
          %{data: %{"text" => "Orphan"}, type: :text},
          scope: scope
        )

      assert :ok = Blocks.destroy_orphan_space_owned_block(space, orphan_block.id, scope: scope)

      persisted_block =
        Block
        |> Ash.Query.filter(id == ^orphan_block.id)
        |> Ash.read_one!(scope: scope)

      assert persisted_block == nil
    end

    test "does not destroy placed blocks" do
      actor = generate(user())
      space = generate(space(author: actor))
      add_membership(space, actor, :owner)
      scope = scope(actor, space)
      {:ok, page} = Page.create(scope: scope)

      {:ok, placed_block} =
        Blocks.create_space_owned_block_on_page(
          space,
          page,
          %{data: %{"text" => "Placed"}, type: :text},
          scope: scope
        )

      assert {:error, :not_found} =
               Blocks.destroy_orphan_space_owned_block(space, placed_block.id, scope: scope)

      assert {:ok, persisted_block} = Ash.get(Block, placed_block.id, scope: scope)
      assert persisted_block.id == placed_block.id
    end
  end

  defp scope(actor, tenant \\ nil) do
    %Scope{actor: actor, tenant: tenant}
  end

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
  end
end
