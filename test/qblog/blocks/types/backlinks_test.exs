defmodule Qblog.Blocks.Types.BacklinksTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Blocks
  alias Qblog.Blocks.Block
  alias Qblog.Scope

  describe "default data" do
    test "creates backlinks blocks with an empty title" do
      actor = generate(user())
      scope = scope(actor)

      assert {:ok, block} = Blocks.create_user_owned_block(%{type: :backlinks}, scope: scope)

      assert block.data == %{"title" => ""}
    end
  end

  describe "block_to_form_params/3" do
    test "uses persisted data" do
      block = %Block{data: %{"title" => "Incoming links"}, type: :backlinks}

      assert %{"title" => "Incoming links"} = Blocks.block_to_form_params(block, %{}, nil)
    end
  end

  describe "update_block/3" do
    test "stores the title" do
      actor = generate(user())
      scope = scope(actor)
      {:ok, block} = Blocks.create_user_owned_block(%{type: :backlinks}, scope: scope)

      assert {:ok, updated_block} =
               Blocks.update_block(
                 block,
                 %{"title" => "Referenced from"},
                 scope: scope
               )

      assert updated_block.data == %{"title" => "Referenced from"}
    end
  end

  describe "validate_data/1" do
    test "rejects invalid data" do
      actor = generate(user())

      assert {:error, _error} =
               Ash.create(
                 Block,
                 %{
                   data: %{},
                   owner_user_id: actor.id,
                   type: :backlinks
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end
  end

  defp scope(actor, tenant \\ nil) do
    %Scope{actor: actor, tenant: tenant}
  end
end
