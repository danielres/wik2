defmodule Qblog.Blocks.BlockPolicyTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Accounts.GroupUserRelation
  alias Qblog.Blocks.Block
  alias Qblog.Blocks.BlockPlacement
  alias Qblog.Scope
  alias Qblog.Wiki.Page

  describe "block access" do
    test "group owner can read and manage their group owned block" do
      %{group: group, group_owned_block: block, owner: owner} = access_fixture()

      assert Ash.can?({block, :read}, scope(owner, group))
      assert Ash.can?({block, :update}, scope(owner, group))
      assert Ash.can?({block, :destroy}, scope(owner, group))
    end

    test "group admin can create and manage their group owned block" do
      %{admin: admin, group: group, group_owned_block: block} = access_fixture()

      assert Ash.can?(
               {Block, :create,
                %{data: %{"text" => "Hello"}, owner_group_id: group.id, type: :text}},
               scope(admin, group)
             )

      assert Ash.can?({block, :read}, scope(admin, group))
      assert Ash.can?({block, :update}, scope(admin, group))
      assert Ash.can?({block, :destroy}, scope(admin, group))
    end

    test "plain member can read a group owned block but cannot manage it" do
      %{group: group, group_owned_block: block, member: member} = access_fixture()

      assert Ash.can?({block, :read}, scope(member, group))
      refute Ash.can?({block, :update}, scope(member, group))
      refute Ash.can?({block, :destroy}, scope(member, group))

      refute Ash.can?(
               {Block, :create,
                %{data: %{"text" => "Hello"}, owner_group_id: group.id, type: :text}},
               scope(member, group)
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

    test "group members can read a user owned block once it is placed on a group page" do
      %{group: group, member: member, placed_user_owned_block: block} = access_fixture()

      assert Ash.can?({block, :read}, scope(member, group))
      refute Ash.can?({block, :update}, scope(member, group))
      refute Ash.can?({block, :destroy}, scope(member, group))
    end
  end

  defp access_fixture do
    group = generate(group())
    owner = generate(user())
    admin = generate(user())
    member = generate(user())
    outsider = generate(user())
    user_owner = generate(user())

    add_membership(group, owner, :owner)
    add_membership(group, admin, :admin)
    add_membership(group, member, :member)
    add_membership(group, user_owner, :member)
    grant_active_telegram_access(group, admin)
    grant_active_telegram_access(group, member)
    grant_active_telegram_access(group, user_owner)

    group_scope = scope(owner, group)
    {:ok, page} = Page.create(authorize?: false, scope: group_scope)

    group_owned_block =
      create_block(
        %{data: %{"text" => "group"}, owner_group_id: group.id, type: :text},
        group_scope
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

    create_placement(page, placed_user_owned_block, group_scope)

    %{
      admin: admin,
      group: group,
      group_owned_block: group_owned_block,
      member: member,
      outsider: outsider,
      owner: owner,
      placed_user_owned_block: placed_user_owned_block,
      user_owned_block: user_owned_block,
      user_owner: user_owner
    }
  end

  defp add_membership(group, user, type) do
    Ash.create!(
      GroupUserRelation,
      %{group_id: group.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Qblog.Accounts
    )
  end

  defp create_block(attrs, scope) do
    Ash.create!(Block, attrs,
      action: :create,
      authorize?: false,
      domain: Qblog.Blocks,
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
      domain: Qblog.Blocks,
      scope: scope
    )
  end

  defp scope(actor, tenant \\ nil), do: %Scope{actor: actor, tenant: tenant}
end
