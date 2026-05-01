defmodule Qblog.Blocks.MarkdownHistoryTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Blocks
  alias Qblog.Scope

  setup do
    actor = generate(user())

    {:ok, actor: actor, scope: %Scope{actor: actor}}
  end

  test "creating a markdown block creates revision 1 as a snapshot", %{scope: scope} do
    assert {:ok, block} = Blocks.create_user_owned_block(%{type: :markdown}, scope: scope)
    assert {:ok, [version]} = Blocks.list_markdown_versions(block, scope: scope)

    assert version.revision == 1
    assert version.storage_kind == :snapshot
    assert version.snapshot_text == nil
    assert version.author_id == scope.actor.id

    assert {:ok, ""} = Blocks.markdown_version_text(version, scope: scope)
  end

  test "creating a non-markdown block creates no history", %{scope: scope} do
    assert {:ok, block} = Blocks.create_user_owned_block(%{type: :text}, scope: scope)
    assert {:ok, []} = Blocks.list_markdown_versions(block, scope: scope)
  end

  test "updating markdown creates a diff revision that reconstructs correctly", %{scope: scope} do
    wikilink_map = Jason.encode!(%{})
    assert {:ok, block} = Blocks.create_user_owned_block(%{type: :markdown}, scope: scope)

    assert {:ok, _updated_block} =
             Blocks.update_block(
               block,
               %{"text" => "first line\nsecond line", "wikilink_map" => wikilink_map},
               scope: scope
             )

    assert {:ok, versions} = Blocks.list_markdown_versions(block, scope: scope)
    assert Enum.map(versions, & &1.revision) == [2, 1]

    version2 = Enum.find(versions, &(&1.revision == 2))
    assert version2.storage_kind == :line_diff

    assert {:ok, "first line\nsecond line"} = Blocks.markdown_version_text(version2, scope: scope)
  end

  test "no-op markdown updates do not create a new version", %{scope: scope} do
    wikilink_map = Jason.encode!(%{})
    assert {:ok, block} = Blocks.create_user_owned_block(%{type: :markdown}, scope: scope)

    assert {:ok, updated_block} =
             Blocks.update_block(
               block,
               %{"text" => "hello", "wikilink_map" => wikilink_map},
               scope: scope
             )

    assert {:ok, versions_before} = Blocks.list_markdown_versions(block, scope: scope)
    assert length(versions_before) == 2

    assert {:ok, ^updated_block} =
             Blocks.update_block(
               updated_block,
               %{"text" => "hello", "wikilink_map" => wikilink_map},
               scope: scope
             )

    assert {:ok, versions_after} = Blocks.list_markdown_versions(block, scope: scope)
    assert length(versions_after) == 2
  end

  test "revision 20 is stored as a snapshot checkpoint", %{scope: scope} do
    wikilink_map = Jason.encode!(%{})
    assert {:ok, block} = Blocks.create_user_owned_block(%{type: :markdown}, scope: scope)

    _block =
      Enum.reduce(1..19, block, fn revision, block ->
        assert {:ok, updated_block} =
                 Blocks.update_block(
                   block,
                   %{"text" => "revision #{revision}", "wikilink_map" => wikilink_map},
                   scope: scope
                 )

        updated_block
      end)

    assert {:ok, versions} = Blocks.list_markdown_versions(block, scope: scope)
    version20 = Enum.find(versions, &(&1.revision == 20))
    assert version20.storage_kind == :snapshot
    assert {:ok, "revision 19"} = Blocks.markdown_version_text(version20, scope: scope)
  end
end
