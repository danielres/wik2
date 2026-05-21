defmodule Wik.Blocks.BlockPolicyTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.Membership
  alias Wik.Blocks.Block
  alias Wik.Blocks.BlockPlacement
  alias Wik.Scope
  alias Wik.Wiki.Page

  describe "block access" do
    test "space owner can read and manage their space owned block" do
      %{space: space, space_owned_block: block, owner: owner} = access_fixture()

      assert Ash.can?({block, :read}, scope(owner, space))
      assert Ash.can?({block, :update}, scope(owner, space))
      assert Ash.can?({block, :destroy}, scope(owner, space))
    end

    test "space admin can create and manage their space owned block" do
      %{admin: admin, space: space, space_owned_block: block} = access_fixture()

      assert Ash.can?(
               {Block, :create,
                %{data: %{"text" => "Hello"}, owner_space_id: space.id, type: :text}},
               scope(admin, space)
             )

      assert Ash.can?({block, :read}, scope(admin, space))
      assert Ash.can?({block, :update}, scope(admin, space))
      assert Ash.can?({block, :destroy}, scope(admin, space))
    end

    test "plain member can read a space owned block but cannot manage it" do
      %{space: space, space_owned_block: block, member: member} = access_fixture()

      assert Ash.can?({block, :read}, scope(member, space))
      refute Ash.can?({block, :update}, scope(member, space))
      refute Ash.can?({block, :destroy}, scope(member, space))

      refute Ash.can?(
               {Block, :create,
                %{data: %{"text" => "Hello"}, owner_space_id: space.id, type: :text}},
               scope(member, space)
             )
    end

    test "user can create and manage their own user owned block" do
      %{user_owned_block: block, user_owner: user} = access_fixture()

      assert Ash.can?(
               {Block, :create,
                %{data: %{"text" => "Hello"}, owner_user_id: user.id, type: :text}},
               scope(user)
             )

      assert Ash.can?({block, :read}, scope(user))
      assert Ash.can?({block, :update}, scope(user))
      assert Ash.can?({block, :destroy}, scope(user))
    end

    test "other users cannot read or manage a private user owned block" do
      %{outsider: outsider, user_owned_block: block} = access_fixture()

      refute Ash.can?({block, :read}, scope(outsider))
      refute Ash.can?({block, :update}, scope(outsider))
      refute Ash.can?({block, :destroy}, scope(outsider))
    end

    test "space members can read a user owned block once it is placed on a space page" do
      %{space: space, member: member, placed_user_owned_block: block} = access_fixture()

      assert Ash.can?({block, :read}, scope(member, space))
      refute Ash.can?({block, :update}, scope(member, space))
      refute Ash.can?({block, :destroy}, scope(member, space))
    end
  end

  defp access_fixture do
    space = generate(space())
    owner = generate(user())
    admin = generate(user())
    member = generate(user())
    outsider = generate(user())
    user_owner = generate(user())

    add_membership(space, owner, :owner)
    add_membership(space, admin, :admin)
    add_membership(space, member, :member)
    add_membership(space, user_owner, :member)
    grant_active_telegram_access(space, admin)
    grant_active_telegram_access(space, member)
    grant_active_telegram_access(space, user_owner)

    space_scope = scope(owner, space)
    {:ok, page} = Page.create(authorize?: false, scope: space_scope)

    space_owned_block =
      create_block(
        %{data: %{"text" => "space"}, owner_space_id: space.id, type: :text},
        space_scope
      )

    user_owned_block =
      create_block(
        %{data: %{"text" => "private"}, owner_user_id: user_owner.id, type: :text},
        scope(user_owner)
      )

    placed_user_owned_block =
      create_block(
        %{data: %{"text" => "placed"}, owner_user_id: user_owner.id, type: :text},
        scope(user_owner)
      )

    create_placement(page, placed_user_owned_block, space_scope)

    %{
      admin: admin,
      space: space,
      space_owned_block: space_owned_block,
      member: member,
      outsider: outsider,
      owner: owner,
      placed_user_owned_block: placed_user_owned_block,
      user_owned_block: user_owned_block,
      user_owner: user_owner
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

  defp create_block(attrs, scope) do
    Ash.create!(Block, attrs,
      action: :create,
      authorize?: false,
      domain: Wik.Blocks,
      scope: scope
    )
  end

  defp create_placement(page, block, scope) do
    Ash.create!(
      BlockPlacement,
      %{
        attachable_id: page.id,
        attachable_type: "page",
        block_id: block.id,
        order_key: "a0"
      },
      action: :create,
      authorize?: false,
      domain: Wik.Blocks,
      scope: scope
    )
  end

  defp scope(actor, tenant \\ nil), do: %Scope{actor: actor, tenant: tenant}
end
