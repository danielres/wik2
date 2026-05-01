defmodule Qblog.Blocks.BlockPlacementPolicyTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Accounts.GroupUserRelation
  alias Qblog.Blocks.Block
  alias Qblog.Blocks.BlockPlacement
  alias Qblog.Scope
  alias Qblog.Wiki.Page

  describe "block placement access" do
    test "group owner can read and manage page placements" do
      %{group: group, owner: owner, placement: placement} = access_fixture()

      assert Ash.can?({placement, :read}, scope(owner, group))
      assert Ash.can?({placement, :update_order}, scope(owner, group))
      assert Ash.can?({placement, :update_area}, scope(owner, group))
      assert Ash.can?({placement, :destroy}, scope(owner, group))
    end

    test "group admin can create and manage a placement for their own user owned block" do
      %{
        admin: admin,
        admin_page: page,
        admin_user_owned_block: block,
        group: group,
        placement: placement
      } =
        access_fixture()

      assert Ash.can?(
               {BlockPlacement, :create,
                %{
                  attachable_id: page.id,
                  attachable_type: "page",
                  block_id: block.id,
                  order_key: "z1",
                  area: nil
                }},
               scope(admin, group)
             )

      assert Ash.can?({placement, :update_order}, scope(admin, group))
      assert Ash.can?({placement, :update_area}, scope(admin, group))
      assert Ash.can?({placement, :destroy}, scope(admin, group))
    end

    test "plain member can read placements but cannot manage them" do
      %{group: group, member: member, placement: placement} = access_fixture()

      assert Ash.can?({placement, :read}, scope(member, group))
      refute Ash.can?({placement, :update_order}, scope(member, group))
      refute Ash.can?({placement, :update_area}, scope(member, group))
      refute Ash.can?({placement, :destroy}, scope(member, group))
    end

    test "plain member cannot create a page placement even for their own block" do
      %{group: group, member: member, member_page: page, member_user_owned_block: block} =
        access_fixture()

      refute Ash.can?(
               {BlockPlacement, :create,
                %{
                  attachable_id: page.id,
                  attachable_type: "page",
                  block_id: block.id,
                  order_key: "z2",
                  area: nil
                }},
               scope(member, group)
             )
    end

    test "group admin cannot create a placement for another user's private block" do
      %{admin: admin, admin_page: page, foreign_user_owned_block: block, group: group} =
        access_fixture()

      refute Ash.can?(
               {BlockPlacement, :create,
                %{
                  attachable_id: page.id,
                  attachable_type: "page",
                  block_id: block.id,
                  order_key: "z3",
                  area: nil
                }},
               scope(admin, group)
             )
    end

    test "outsider cannot read or manage another group's placement" do
      %{group: group, outsider: outsider, placement: placement} = access_fixture()

      refute Ash.can?({placement, :read}, scope(outsider, group))
      refute Ash.can?({placement, :update_order}, scope(outsider, group))
      refute Ash.can?({placement, :update_area}, scope(outsider, group))
      refute Ash.can?({placement, :destroy}, scope(outsider, group))
    end
  end

  defp access_fixture do
    group = generate(group())
    owner = generate(user())
    admin = generate(user())
    member = generate(user())
    outsider = generate(user())
    foreign_user = generate(user())

    add_membership(group, owner, :owner)
    add_membership(group, admin, :admin)
    add_membership(group, member, :member)
    grant_active_telegram_access(group, admin)
    grant_active_telegram_access(group, member)

    owner_scope = scope(owner, group)
    {:ok, page} = Page.create(authorize?: false, scope: owner_scope)

    admin_scope = scope(admin, group)
    {:ok, admin_page} = Page.create(authorize?: false, scope: admin_scope)

    member_scope = scope(member, group)
    {:ok, member_page} = Page.create(authorize?: false, scope: member_scope)

    group_owned_block =
      create_block(
        %{data: %{"text" => "group"}, owner_group_id: group.id, type: :text},
        owner_scope
      )

    admin_user_owned_block =
      create_block(
        %{data: %{"text" => "admin"}, owner_user_id: admin.id, type: :text},
        scope(admin)
      )

    member_user_owned_block =
      create_block(
        %{data: %{"text" => "member"}, owner_user_id: member.id, type: :text},
        scope(member)
      )

    foreign_user_owned_block =
      create_block(
        %{data: %{"text" => "foreign"}, owner_user_id: foreign_user.id, type: :text},
        scope(foreign_user)
      )

    placement = create_placement(page, group_owned_block, owner_scope)

    %{
      admin: admin,
      admin_page: admin_page,
      admin_user_owned_block: admin_user_owned_block,
      foreign_user_owned_block: foreign_user_owned_block,
      group: group,
      member: member,
      member_page: member_page,
      member_user_owned_block: member_user_owned_block,
      outsider: outsider,
      owner: owner,
      placement: placement
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
        order_key: "a0",
        area: nil
      },
      action: :create,
      authorize?: false,
      domain: Qblog.Blocks,
      scope: scope
    )
  end

  defp scope(actor, tenant \\ nil), do: %Scope{actor: actor, tenant: tenant}
end
