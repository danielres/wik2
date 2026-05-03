defmodule Wik.Blocks.Types.SoundCloudTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Blocks
  alias Wik.Blocks.Block
  alias Wik.Scope

  describe "validate_data/1" do
    test "allows blank soundcloud url on create" do
      actor = generate(user())

      assert {:ok, _block} =
               Ash.create(
                 Block,
                 %{
                   data: %{"title" => "", "url" => ""},
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
                   data: %{"title" => "", "url" => 123},
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
                   data: %{"title" => "", "url" => "https://soundcloud.com/forss/flickermood"},
                   owner_user_id: actor.id,
                   type: :soundcloud
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end
  end

  describe "update_block/3" do
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
               Blocks.update_block(block, %{"title" => "", "url" => embed_url}, scope: scope)

      assert updated_block.data == %{"title" => "", "url" => embed_url}
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
               Blocks.update_block(block, %{"title" => "", "url" => iframe}, scope: scope)

      assert updated_block.data == %{
               "title" => "",
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
                 %{"title" => "", "url" => "https://soundcloud.com/forss/flickermood"},
                 scope: scope
               )
    end
  end

  defp scope(actor, tenant \\ nil) do
    %Scope{actor: actor, tenant: tenant}
  end
end
