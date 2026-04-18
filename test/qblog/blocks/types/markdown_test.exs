defmodule Qblog.Blocks.Types.MarkdownTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Blocks
  alias Qblog.Blocks.Block
  alias Qblog.Scope
  alias Qblog.Wiki.PageTree
  alias Qblog.Wiki.PageTree.Node

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
      wikilink_map = Jason.encode!(%{"recipes" => 1, "recipes/soup" => 2})

      assert {:ok, updated_block} =
               Blocks.update_block(
                 block,
                 %{
                   "text" =>
                     "\r\n\r\n## Title  \r\n\r\n[[recipes]]\r\n\r\n[[recipes/soup]]  \r\n\r\n",
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

      stale_map = Jason.encode!(%{"recipes/cake" => 1})

      assert {:ok, updated_block} =
               Blocks.update_block(
                 block,
                 %{"text" => "[[recipes/cake]]", "wikilink_map" => stale_map},
                 scope: scope
               )

      assert updated_block.data == %{"text" => "[[node:1]]"}
    end

    test "raises when the submitted wikilink map is invalid", %{scope: scope} do
      {:ok, block} = Blocks.create_user_owned_block(%{type: :markdown}, scope: scope)

      assert_raise MatchError, fn ->
        Blocks.update_block(
          block,
          %{"text" => "[[recipes]]", "wikilink_map" => "not-json"},
          scope: scope
        )
      end
    end

    test "keeps canonical wikilinks visible when building form params", %{scope: _scope} do
      block = %Block{data: %{"text" => "[[node:1]] and [[node:2]]"}, type: :markdown}

      assert %{"text" => "[[recipes]] and [[recipes/soup]]"} =
               Blocks.block_to_form_params(block, %{}, page_tree_fixture())
    end
  end

  defp scope(actor, tenant \\ nil) do
    %Scope{actor: actor, tenant: tenant}
  end

  defp page_tree_fixture do
    %PageTree{
      nodes: [
        %Node{id: 1, parent_id: nil, slug: "recipes", title: "Recipes"},
        %Node{id: 2, parent_id: 1, slug: "soup", title: "Soup"}
      ]
    }
  end
end
