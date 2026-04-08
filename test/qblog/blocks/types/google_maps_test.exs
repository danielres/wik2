defmodule Qblog.Blocks.Types.GoogleMapsTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Blocks
  alias Qblog.Blocks.Block
  alias Qblog.Scope

  describe "validate_data/1" do
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
  end

  defp scope(actor, tenant \\ nil) do
    %Scope{actor: actor, tenant: tenant}
  end
end
