defmodule Wik.Blocks.Types.MarkdownTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Blocks
  alias Wik.Blocks.Block
  alias Wik.Scope
  alias Wik.Wiki.PageTree
  alias Wik.Wiki.PageTree.Node

  setup do
    actor = generate(user())

    {:ok, scope: scope(actor)}
  end

  describe "validate_data/1" do
    test "creates blank markdown blocks with the expected data shape", %{scope: scope} do
      assert {:ok, block} = Blocks.create_user_owned_block(%{type: :markdown}, scope: scope)

      assert block.data == %{"text" => ""}
      assert %{"text" => ""} = Blocks.block_to_form_params(block, %{}, page_tree_fixture())
    end

    test "allows blank markdown text on create" do
      actor = generate(user())

      assert {:ok, _block} =
               Ash.create(
                 Block,
                 %{
                   data: %{"text" => " "},
                   owner_user_id: actor.id,
                   type: :markdown
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end

    test "fails when markdown block text is missing" do
      actor = generate(user())

      assert {:error, _error} =
               Ash.create(
                 Block,
                 %{
                   data: %{},
                   owner_user_id: actor.id,
                   type: :markdown
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end

    test "fails when markdown block text is not a string" do
      actor = generate(user())

      assert {:error, _error} =
               Ash.create(
                 Block,
                 %{
                   data: %{"text" => 123},
                   owner_user_id: actor.id,
                   type: :markdown
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end
  end

  describe "update_block/3" do
    test "normalizes the submitted markdown text", %{scope: scope} do
      {:ok, block} = Blocks.create_user_owned_block(%{type: :markdown}, scope: scope)
      wikilink_map = Jason.encode!(%{"Soups" => 1, "Soups/Vegetable Soup" => 2})

      assert {:ok, updated_block} =
               Blocks.update_block(
                 block,
                 %{
                   "text" =>
                     "\r\n\r\n## Title  \r\n\r\n[[Soups]]\r\n\r\n[[Soups/Vegetable Soup]]  \r\n\r\n",
                   "wikilink_map" => wikilink_map
                 },
                 scope: scope
               )

      assert updated_block.data == %{
               "text" => "## Title\n\n[[node:1]]\n\n[[node:2]]"
             }
    end

    test "uses the submitted wikilink map when canonicalizing a stale editor", %{scope: scope} do
      {:ok, block} = Blocks.create_user_owned_block(%{type: :markdown}, scope: scope)

      stale_map = Jason.encode!(%{"Soups/Vegetable Soup" => 1})

      assert {:ok, updated_block} =
               Blocks.update_block(
                 block,
                 %{"text" => "[[Soups/Vegetable Soup]]", "wikilink_map" => stale_map},
                 scope: scope
               )

      assert updated_block.data == %{"text" => "[[node:1]]"}
    end

    test "raises when the submitted wikilink map is invalid", %{scope: scope} do
      {:ok, block} = Blocks.create_user_owned_block(%{type: :markdown}, scope: scope)

      assert_raise MatchError, fn ->
        Blocks.update_block(
          block,
          %{"text" => "[[Soups]]", "wikilink_map" => "not-json"},
          scope: scope
        )
      end
    end

    test "keeps canonical wikilinks visible when building form params", %{scope: _scope} do
      block = %Block{data: %{"text" => "[[node:1]] and [[node:2]]"}, type: :markdown}

      assert %{"text" => "[[Soups]] and [[Soups/Vegetable Soup]]"} =
               Blocks.block_to_form_params(block, %{}, page_tree_fixture())
    end
  end

  defp scope(actor, tenant \\ nil) do
    %Scope{actor: actor, tenant: tenant}
  end

  defp page_tree_fixture do
    %PageTree{
      nodes: [
        %Node{
          id: 1,
          page_id: "11111111-1111-1111-1111-111111111111",
          parent_id: nil,
          slug: "soups",
          title: "Soups"
        },
        %Node{
          id: 2,
          page_id: "22222222-2222-2222-2222-222222222222",
          parent_id: 1,
          slug: "vegetable-soup",
          title: "Vegetable Soup"
        }
      ]
    }
  end
end
