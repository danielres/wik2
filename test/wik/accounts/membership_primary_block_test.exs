defmodule Wik.Accounts.MembershipPrimaryBlockTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts
  alias Wik.Accounts.Membership
  alias Wik.Blocks
  alias Wik.Scope

  describe "primary block" do
    test "returns nil when the membership has no primary block" do
      %{membership: membership, scope: scope} = membership_fixture()

      assert {:ok, nil} = Accounts.get_primary_block(membership, scope: scope)
    end

    test "creates and reuses a user-owned markdown primary block" do
      %{membership: membership, scope: scope} = membership_fixture()

      assert {:ok, updated_membership, block} =
               Accounts.get_or_create_primary_block(membership, scope: scope)

      assert block.type == :markdown
      assert block.owner_user_id == membership.user_id
      assert updated_membership.primary_block_id == block.id

      assert {:ok, fetched_block} = Accounts.get_primary_block(updated_membership, scope: scope)
      assert fetched_block.id == block.id

      assert {:ok, _membership, reused_block} =
               Accounts.get_or_create_primary_block(updated_membership, scope: scope)

      assert reused_block.id == block.id
    end

    test "updates the membership primary block" do
      %{membership: membership, scope: scope} = membership_fixture()

      assert {:ok, block} =
               Accounts.update_primary_block(membership, %{"text" => "Hello profile"},
                 scope: scope
               )

      assert block.data == %{"text" => "Hello profile"}
    end

    test "rejects a primary block not owned by the membership user" do
      %{membership: membership, scope: scope} = membership_fixture()
      other_user = generate(user())

      assert {:ok, block} =
               Blocks.create_user_owned_block(%{type: :markdown}, scope: scope(other_user))

      assert {:error, _error} =
               Ash.update(
                 membership,
                 %{primary_block_id: block.id},
                 action: :set_primary_block,
                 scope: scope
               )
    end

    test "rejects a non-markdown primary block" do
      %{membership: membership, scope: scope} = membership_fixture()
      assert {:ok, block} = Blocks.create_user_owned_block(%{type: :text}, scope: scope)

      assert {:error, _error} =
               Ash.update(
                 membership,
                 %{primary_block_id: block.id},
                 action: :set_primary_block,
                 scope: scope
               )
    end
  end

  defp membership_fixture do
    user = generate(user())
    space = generate(space())
    add_membership(space, user, :member)
    membership = reload_membership(space, user)

    %{membership: membership, scope: scope(user, space)}
  end

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Accounts
    )
  end

  defp reload_membership(space, user) do
    space.id
    |> Accounts.get_membership(user.id)
    |> elem(1)
  end

  defp scope(actor, tenant \\ nil), do: %Scope{actor: actor, tenant: tenant}
end
