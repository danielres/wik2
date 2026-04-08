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

  describe "Block validations" do
    test "fails when no owner is set" do
      actor = generate(user())

      assert {:error, _error} =
               Ash.create(
                 Block,
                 %{
                   data: %{"text" => "Hello"},
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
                   data: %{"text" => "Hello"},
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
                   data: %{"text" => " "},
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
                   data: %{"text" => 123},
                   owner_user_id: actor.id,
                   type: :text
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end

    test "allows blank google maps url on create" do
      actor = generate(user())

      assert {:ok, _block} =
               Ash.create(
                 Block,
                 %{
                   data: %{"url" => ""},
                   owner_user_id: actor.id,
                   type: :google_maps
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end

    test "fails when google maps url is not a string" do
      actor = generate(user())

      assert {:error, _error} =
               Ash.create(
                 Block,
                 %{
                   data: %{"url" => 123},
                   owner_user_id: actor.id,
                   type: :google_maps
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end

    test "fails when google maps url is not an embed url" do
      actor = generate(user())

      assert {:error, _error} =
               Ash.create(
                 Block,
                 %{
                   data: %{"url" => "https://www.google.com/maps/place/Berlin"},
                   owner_user_id: actor.id,
                   type: :google_maps
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end

    test "allows blank soundcloud url on create" do
      actor = generate(user())

      assert {:ok, _block} =
               Ash.create(
                 Block,
                 %{
                   data: %{"url" => ""},
                   owner_user_id: actor.id,
                   type: :soundcloud
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end

    test "fails when soundcloud url is not a string" do
      actor = generate(user())

      assert {:error, _error} =
               Ash.create(
                 Block,
                 %{
                   data: %{"url" => 123},
                   owner_user_id: actor.id,
                   type: :soundcloud
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end

    test "fails when soundcloud url is not an embed url" do
      actor = generate(user())

      assert {:error, _error} =
               Ash.create(
                 Block,
                 %{
                   data: %{"url" => "https://soundcloud.com/forss/flickermood"},
                   owner_user_id: actor.id,
                   type: :soundcloud
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end

    test "allows blank youtube url on create" do
      actor = generate(user())

      assert {:ok, _block} =
               Ash.create(
                 Block,
                 %{
                   data: %{"url" => ""},
                   owner_user_id: actor.id,
                   type: :youtube
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end

    test "fails when youtube url is not a string" do
      actor = generate(user())

      assert {:error, _error} =
               Ash.create(
                 Block,
                 %{
                   data: %{"url" => 123},
                   owner_user_id: actor.id,
                   type: :youtube
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end

    test "fails when youtube url is not an embed url" do
      actor = generate(user())

      assert {:error, _error} =
               Ash.create(
                 Block,
                 %{
                   data: %{"url" => "https://www.youtube.com/watch?v=dQw4w9WgXcQ"},
                   owner_user_id: actor.id,
                   type: :youtube
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end
  end

  describe "update_block/3" do
    test "accepts a raw google maps embed url" do
      actor = generate(user())
      scope = scope(actor)

      {:ok, block} =
        Blocks.create_user_owned_block(
          %{type: :google_maps},
          scope: scope
        )

      embed_url = "https://www.google.com/maps/embed?pb=example"

      assert {:ok, updated_block} =
               Blocks.update_block(block, %{"url" => embed_url}, scope: scope)

      assert updated_block.data == %{"url" => embed_url}
    end

    test "accepts iframe embed code and stores only the url" do
      actor = generate(user())
      scope = scope(actor)

      {:ok, block} =
        Blocks.create_user_owned_block(
          %{type: :google_maps},
          scope: scope
        )

      iframe =
        ~s(<iframe src="https://www.google.com/maps/embed?pb=example&amp;foo=bar" width="600" height="450"></iframe>)

      assert {:ok, updated_block} =
               Blocks.update_block(block, %{"url" => iframe}, scope: scope)

      assert updated_block.data == %{
               "url" => "https://www.google.com/maps/embed?pb=example&foo=bar"
             }
    end

    test "rejects a regular google maps url" do
      actor = generate(user())
      scope = scope(actor)

      {:ok, block} =
        Blocks.create_user_owned_block(
          %{type: :google_maps},
          scope: scope
        )

      assert {:error, _error} =
               Blocks.update_block(
                 block,
                 %{"url" => "https://www.google.com/maps/place/Berlin"},
                 scope: scope
               )
    end

    test "accepts a raw soundcloud embed url" do
      actor = generate(user())
      scope = scope(actor)

      {:ok, block} =
        Blocks.create_user_owned_block(
          %{type: :soundcloud},
          scope: scope
        )

      embed_url =
        "https://w.soundcloud.com/player/?url=https%3A//api.soundcloud.com/tracks/293&color=%23ff5500"

      assert {:ok, updated_block} =
               Blocks.update_block(block, %{"url" => embed_url}, scope: scope)

      assert updated_block.data == %{"url" => embed_url}
    end

    test "accepts soundcloud iframe embed code and stores only the url" do
      actor = generate(user())
      scope = scope(actor)

      {:ok, block} =
        Blocks.create_user_owned_block(
          %{type: :soundcloud},
          scope: scope
        )

      iframe =
        ~s(<iframe src="https://w.soundcloud.com/player/?url=https%3A//api.soundcloud.com/tracks/293&amp;color=%23ff5500"></iframe>)

      assert {:ok, updated_block} =
               Blocks.update_block(block, %{"url" => iframe}, scope: scope)

      assert updated_block.data == %{
               "url" =>
                 "https://w.soundcloud.com/player/?url=https%3A//api.soundcloud.com/tracks/293&color=%23ff5500"
             }
    end

    test "rejects a regular soundcloud url" do
      actor = generate(user())
      scope = scope(actor)

      {:ok, block} =
        Blocks.create_user_owned_block(
          %{type: :soundcloud},
          scope: scope
        )

      assert {:error, _error} =
               Blocks.update_block(
                 block,
                 %{"url" => "https://soundcloud.com/forss/flickermood"},
                 scope: scope
               )
    end

    test "accepts a raw youtube embed url" do
      actor = generate(user())
      scope = scope(actor)

      {:ok, block} =
        Blocks.create_user_owned_block(
          %{type: :youtube},
          scope: scope
        )

      embed_url = "https://www.youtube.com/embed/dQw4w9WgXcQ?si=example"

      assert {:ok, updated_block} =
               Blocks.update_block(block, %{"url" => embed_url}, scope: scope)

      assert updated_block.data == %{
               "url" => "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?si=example"
             }
    end

    test "accepts youtube iframe embed code and stores only the url" do
      actor = generate(user())
      scope = scope(actor)

      {:ok, block} =
        Blocks.create_user_owned_block(
          %{type: :youtube},
          scope: scope
        )

      iframe =
        ~s(<iframe src="https://www.youtube.com/embed/dQw4w9WgXcQ?si=example&amp;start=30" allowfullscreen></iframe>)

      assert {:ok, updated_block} =
               Blocks.update_block(block, %{"url" => iframe}, scope: scope)

      assert updated_block.data == %{
               "url" =>
                 "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?si=example&start=30"
             }
    end

    test "rejects a regular youtube url" do
      actor = generate(user())
      scope = scope(actor)

      {:ok, block} =
        Blocks.create_user_owned_block(
          %{type: :youtube},
          scope: scope
        )

      assert {:error, _error} =
               Blocks.update_block(
                 block,
                 %{"url" => "https://www.youtube.com/watch?v=dQw4w9WgXcQ"},
                 scope: scope
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

  describe "BlockPlacement ordering integrity" do
    test "fails when the same order key is reused in the same container" do
      actor = generate(user())
      group = generate(group(author: actor))
      scope = scope(actor, group)
      {:ok, page} = Page.create(scope: scope)

      {:ok, block1} =
        Blocks.create_user_owned_block(%{data: %{"text" => "First"}, type: :text}, scope: scope)

      {:ok, block2} =
        Blocks.create_user_owned_block(%{data: %{"text" => "Second"}, type: :text}, scope: scope)

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
