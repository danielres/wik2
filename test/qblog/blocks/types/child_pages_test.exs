defmodule Qblog.Blocks.Types.ChildPagesTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Blocks
  alias Qblog.Blocks.Block
  alias Qblog.Scope

  test "allows blank child pages data on create" do
    actor = generate(user())

    assert {:ok, _block} =
             Ash.create(
               Block,
               %{
                 data: %{"source" => "current_page", "title" => ""},
                 owner_user_id: actor.id,
                 type: :child_pages
               },
               action: :create,
               scope: scope(actor)
             )
  end

  test "fails when source is invalid" do
    actor = generate(user())

    assert {:error, _error} =
             Ash.create(
               Block,
               %{
                 data: %{"source" => "invalid", "title" => ""},
                 owner_user_id: actor.id,
                 type: :child_pages
               },
               action: :create,
               scope: scope(actor)
             )
  end

  describe "update_block/3" do
    test "stores the selected source page node" do
      actor = generate(user())
      scope = scope(actor)

      {:ok, block} =
        Blocks.create_user_owned_block(
          %{type: :child_pages},
          scope: scope
        )

      assert {:ok, updated_block} =
               Blocks.update_block(block, %{"source_page" => "2", "title" => ""}, scope: scope)

      assert updated_block.data == %{"node_id" => 2, "source" => "node", "title" => ""}
    end

    test "keeps current_page when it is explicitly selected" do
      actor = generate(user())
      scope = scope(actor)

      {:ok, block} =
        Blocks.create_user_owned_block(
          %{type: :child_pages},
          scope: scope
        )

      assert {:ok, updated_block} =
               Blocks.update_block(block, %{"source_page" => "current_page", "title" => ""},
                 scope: scope
               )

      assert updated_block.data == %{"source" => "current_page", "title" => ""}
    end
  end

  describe "block_to_form_params/3" do
    test "exposes the selected source page for the form" do
      block =
        %Block{
          data: %{"node_id" => 2, "source" => "node", "title" => "Related pages"},
          type: :child_pages
        }

      assert %{
               "node_id" => "2",
               "source" => "node",
               "source_page" => "2",
               "title" => "Related pages"
             } = Blocks.block_to_form_params(block, %{}, nil)
    end

    test "uses persisted title values" do
      block = %Block{
        data: %{"source" => "current_page", "title" => "Related pages"},
        type: :child_pages
      }

      assert %{
               "title" => "Related pages"
             } = Blocks.block_to_form_params(block, %{}, nil)
    end
  end

  defp scope(actor, tenant \\ nil) do
    %Scope{actor: actor, tenant: tenant}
  end
end
