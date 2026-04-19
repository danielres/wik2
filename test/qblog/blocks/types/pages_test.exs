defmodule Qblog.Blocks.Types.PagesTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Blocks
  alias Qblog.Blocks.Block
  alias Qblog.Scope

  describe "default data" do
    test "creates pages blocks with root source and depth 1", %{test: _test} do
      actor = generate(user())
      scope = scope(actor)

      assert {:ok, block} =
               Blocks.create_user_owned_block(
                 %{type: :pages},
                 scope: scope
               )

      assert block.data == %{"depth" => 1, "source_node" => "root", "title" => ""}
    end
  end

  describe "block_to_form_params/3" do
    test "uses persisted data" do
      block = %Block{data: %{"depth" => 2, "source_node" => 3, "title" => "Docs"}, type: :pages}

      assert %{
               "depth" => 2,
               "source_node" => "3",
               "title" => "Docs"
             } = Blocks.block_to_form_params(block, %{}, nil)
    end
  end

  describe "update_block/3" do
    test "stores root source, depth, and title" do
      actor = generate(user())
      scope = scope(actor)

      {:ok, block} = Blocks.create_user_owned_block(%{type: :pages}, scope: scope)

      assert {:ok, updated_block} =
               Blocks.update_block(
                 block,
                 %{"depth" => "3", "source_node" => "root", "title" => "All pages"},
                 scope: scope
               )

      assert updated_block.data == %{
               "depth" => 3,
               "source_node" => "root",
               "title" => "All pages"
             }
    end

    test "stores selected source node" do
      actor = generate(user())
      scope = scope(actor)

      {:ok, block} = Blocks.create_user_owned_block(%{type: :pages}, scope: scope)

      assert {:ok, updated_block} =
               Blocks.update_block(
                 block,
                 %{"depth" => "1", "source_node" => "42", "title" => ""},
                 scope: scope
               )

      assert updated_block.data == %{"depth" => 1, "source_node" => 42, "title" => ""}
    end
  end

  describe "validate_data/1" do
    test "rejects invalid data" do
      actor = generate(user())

      assert {:error, _error} =
               Ash.create(
                 Block,
                 %{
                   data: %{"depth" => 0, "source_node" => "root", "title" => ""},
                   owner_user_id: actor.id,
                   type: :pages
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
