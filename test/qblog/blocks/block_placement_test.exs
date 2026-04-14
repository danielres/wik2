defmodule Qblog.Blocks.BlockPlacementTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Accounts.GroupUserRelation
  alias Qblog.Blocks
  alias Qblog.Blocks.BlockPlacement
  alias Qblog.Scope
  alias Qblog.Wiki.Page

  describe "ordering integrity" do
    test "fails when the same order key is reused in the same container" do
      actor = generate(user())
      group = generate(group(author: actor))
      add_membership(group, actor, :owner)
      scope = make_scope(actor, group)
      {:ok, page} = Page.create(scope: scope)

      {:ok, block1} =
        Blocks.create_user_owned_block(%{data: %{"text" => "First"}, type: :text}, scope: scope)

      {:ok, block2} =
        Blocks.create_user_owned_block(%{data: %{"text" => "Second"}, type: :text}, scope: scope)

      {:ok, placement1} = Blocks.place_block_on_page(block1, page, scope: scope)

      assert {:error, _error} =
               Ash.create(
                 BlockPlacement,
                 %{
                   attachable_id: page.id,
                   attachable_type: "page",
                   block_id: block2.id,
                   order_key: placement1.order_key,
                   width: "full"
                 },
                 action: :create,
                 scope: scope
               )
    end
  end

  defp make_scope(actor, tenant) do
    %Scope{actor: actor, tenant: tenant}
  end

  defp add_membership(group, user, type) do
    Ash.create!(
      GroupUserRelation,
      %{group_id: group.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Qblog.Accounts
    )
  end
end
