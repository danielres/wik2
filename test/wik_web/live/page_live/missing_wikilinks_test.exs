defmodule WikWeb.PageLive.MissingWikilinksTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Phoenix.LiveView.Socket
  alias Wik.Accounts.Membership
  alias Wik.Blocks
  alias Wik.Blocks.Block
  alias Wik.Blocks.Types.Markdown, as: MarkdownBlock
  alias Wik.Scope
  alias Wik.Wiki
  alias WikWeb.PageLive.MissingWikilinks

  test "canonicalizes a clicked missing visible wikilink after creating the target page" do
    %{scope: scope, source_block: source_block, target_node: target_node} =
      source_and_target_fixture("[[New Page]] and [[ New Page ]]")

    source =
      source_params(source_block, "New Page")

    socket =
      socket(scope, target_node)
      |> MissingWikilinks.canonicalize_source(source)

    assert socket.assigns.node.id == target_node.id

    assert {:ok, block} = Block.get_by_id(source_block.id, scope: scope)
    assert block.data["text"] == "[[node:#{target_node.id}]] and [[node:#{target_node.id}]]"
  end

  test "skips canonicalization when the source block is locked" do
    %{scope: scope, source_block: source_block, target_node: target_node} =
      source_and_target_fixture("[[New Page]]")

    socket =
      socket(scope, target_node, %{source_block.id => %{}})
      |> MissingWikilinks.canonicalize_source(source_params(source_block, "New Page"))

    assert socket.assigns.node.id == target_node.id

    assert {:ok, block} = Block.get_by_id(source_block.id, scope: scope)
    assert block.data["text"] == "[[New Page]]"
  end

  test "skips canonicalization when the source text has changed" do
    %{scope: scope, source_block: source_block, target_node: target_node} =
      source_and_target_fixture("[[New Page]]")

    assert {:ok, changed_block} =
             Blocks.update_block(source_block, %{"text" => "[[Changed]]"}, scope: scope)

    socket(scope, target_node)
    |> MissingWikilinks.canonicalize_source(source_params(source_block, "New Page"))

    assert {:ok, block} = Block.get_by_id(changed_block.id, scope: scope)
    assert block.data["text"] == "[[Changed]]"
  end

  defp source_and_target_fixture(source_text) do
    actor = generate(user())
    space = generate(space(author: actor))
    add_membership(space, actor, :owner)
    scope = %Scope{actor: actor, tenant: space}

    assert {:ok, _source_node, source_page} =
             Wiki.ensure_page_and_node_at_path("home", scope: scope, load: [:author])

    assert {:ok, source_block} =
             Blocks.create_user_owned_block_on_page(
               source_page,
               %{type: :markdown, data: %{"text" => source_text}},
               scope: scope
             )

    assert {:ok, target_node, _target_page} =
             Wiki.ensure_page_and_node_at_path(
               "new-page",
               scope: scope,
               load: [:author],
               title_path: "New Page"
             )

    %{scope: scope, source_block: source_block, target_node: target_node}
  end

  defp source_params(source_block, title_path) do
    %{
      "wikilink_source_block_id" => source_block.id,
      "wikilink_source_text_hash" => MarkdownBlock.source_text_hash(source_block.data["text"]),
      "wikilink_source_title_path" => title_path
    }
  end

  defp socket(scope, node, locks \\ %{}) do
    %Socket{
      assigns: %{
        current_scope: scope,
        locks: locks,
        node: node
      }
    }
  end

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
  end
end
