defmodule Qblog.Blocks.Types.YouTubeTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Blocks
  alias Qblog.Blocks.Block
  alias Qblog.Scope

  describe "validate_data/1" do
    test "allows blank youtube url on create" do
      actor = generate(user())

      assert {:ok, _block} =
               Ash.create(
                 Block,
                 %{
                   data: %{"title" => "", "url" => ""},
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
                   data: %{"title" => "", "url" => 123},
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
                   data: %{"title" => "", "url" => "https://www.youtube.com/watch?v=dQw4w9WgXcQ"},
                   owner_user_id: actor.id,
                   type: :youtube
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end
  end

  describe "update_block/3" do
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
               Blocks.update_block(block, %{"title" => "", "url" => embed_url}, scope: scope)

      assert updated_block.data == %{
               "title" => "",
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
               Blocks.update_block(block, %{"title" => "", "url" => iframe}, scope: scope)

      assert updated_block.data == %{
               "title" => "",
               "url" => "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?si=example&start=30"
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
                 %{"title" => "", "url" => "https://www.youtube.com/watch?v=dQw4w9WgXcQ"},
                 scope: scope
               )
    end

    test "switches to another embed provider when the input matches it" do
      actor = generate(user())
      scope = scope(actor)

      {:ok, block} =
        Blocks.create_user_owned_block(
          %{type: :youtube},
          scope: scope
        )

      soundcloud_embed_url =
        "https://w.soundcloud.com/player/?url=https%3A//api.soundcloud.com/tracks/293&color=%23ff5500"

      assert {:ok, updated_block} =
               Blocks.update_block(block, %{"title" => "", "url" => soundcloud_embed_url},
                 scope: scope
               )

      assert updated_block.type == :soundcloud
      assert updated_block.data == %{"title" => "", "url" => soundcloud_embed_url}
    end
  end

  defp scope(actor, tenant \\ nil) do
    %Scope{actor: actor, tenant: tenant}
  end
end
