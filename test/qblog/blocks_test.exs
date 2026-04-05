defmodule Qblog.BlocksTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Blocks
  alias Qblog.Blocks.Block
  alias Qblog.Blocks.BlockPlacement
  alias Qblog.Scope
  alias Qblog.Wiki.Page

  describe "create_user_owned_block/2" do
    test "sets author and user owner and clears group owner" do
      actor = generate(user())
      group = generate(group())

      assert {:ok, block} =
               Blocks.create_user_owned_block(
                 %{
                   data: %{text: "Hello"},
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
                   data: %{text: "Hello"},
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

  describe "Block validations" do
    test "fails when no owner is set" do
      actor = generate(user())

      assert {:error, _error} =
               Ash.create(
                 Block,
                 %{
                   data: %{text: "Hello"},
                   type: :text
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end

    test "fails when both owners are set" do
      actor = generate(user())
      group = generate(group())

      assert {:error, _error} =
               Ash.create(
                 Block,
                 %{
                   data: %{text: "Hello"},
                   owner_group_id: group.id,
                   owner_user_id: actor.id,
                   type: :text
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end

    test "allows blank text block data on create" do
      actor = generate(user())

      assert {:ok, _block} =
               Ash.create(
                 Block,
                 %{
                   data: %{text: " "},
                   owner_user_id: actor.id,
                   type: :text
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end

    test "fails when text block text is not a string" do
      actor = generate(user())

      assert {:error, _error} =
               Ash.create(
                 Block,
                 %{
                   data: %{text: 123},
                   owner_user_id: actor.id,
                   type: :text
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end
  end

  describe "place_block_on_page/3" do
    test "creates a placement for the parent" do
      actor = generate(user())
      group = generate(group(author: actor))
      scope = scope(actor, group)
      {:ok, page} = Page.create(scope: scope)

      {:ok, block} =
        Blocks.create_user_owned_block(%{data: %{text: "Hello"}, type: :text}, scope: scope)

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
        Blocks.create_user_owned_block(%{data: %{text: "First"}, type: :text}, scope: scope)

      {:ok, block2} =
        Blocks.create_user_owned_block(%{data: %{text: "Second"}, type: :text}, scope: scope)

      assert {:ok, placement1} = Blocks.place_block_on_page(block1, page, scope: scope)
      assert {:ok, placement2} = Blocks.place_block_on_page(block2, page, scope: scope)

      assert placement1.order_key < placement2.order_key
    end
  end

  describe "BlockPlacement ordering integrity" do
    test "fails when the same order key is reused in the same container" do
      actor = generate(user())
      group = generate(group(author: actor))
      scope = scope(actor, group)
      {:ok, page} = Page.create(scope: scope)

      {:ok, block1} =
        Blocks.create_user_owned_block(%{data: %{text: "First"}, type: :text}, scope: scope)

      {:ok, block2} =
        Blocks.create_user_owned_block(%{data: %{text: "Second"}, type: :text}, scope: scope)

      {:ok, placement1} = Blocks.place_block_on_page(block1, page, scope: scope)

      assert {:error, _error} =
               Ash.create(
                 BlockPlacement,
                 %{
                   attachable_id: page.id,
                   attachable_type: "page",
                   block_id: block2.id,
                   order_key: placement1.order_key
                 },
                 action: :create,
                 scope: scope
               )
    end
  end

  defp scope(actor, tenant \\ nil) do
    %Scope{actor: actor, tenant: tenant}
  end
end
