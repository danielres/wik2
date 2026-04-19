defmodule Qblog.Blocks.Types.TextTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Blocks.Block
  alias Qblog.Scope

  describe "block_to_form_params/3" do
    test "uses persisted text" do
      block = %Block{data: %{"text" => "Hello"}, type: :text}

      assert %{"text" => "Hello"} = Qblog.Blocks.block_to_form_params(block, %{}, nil)
    end
  end

  describe "update_block/3" do
    test "stores submitted text" do
      actor = generate(user())
      scope = scope(actor)

      {:ok, block} =
        Qblog.Blocks.create_user_owned_block(
          %{type: :text},
          scope: scope
        )

      assert {:ok, updated_block} =
               Qblog.Blocks.update_block(block, %{"text" => "Updated"}, scope: scope)

      assert updated_block.data == %{"text" => "Updated"}
    end
  end

  describe "validate_data/1" do
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
  end

  defp scope(actor, tenant \\ nil) do
    %Scope{actor: actor, tenant: tenant}
  end
end
