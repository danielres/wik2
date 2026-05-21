defmodule Wik.Blocks.BlockPlacementPolicyTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.Membership
  alias Wik.Blocks.Block
  alias Wik.Blocks.BlockPlacement
  alias Wik.Scope
  alias Wik.Wiki.Page

  describe "block placement access" do
    test "space owner can read and manage page placements" do
      %{space: space, owner: owner, placement: placement} = access_fixture()

      assert Ash.can?({placement, :read}, scope(owner, space))
      assert Ash.can?({placement, :update_order}, scope(owner, space))
      assert Ash.can?({placement, :update_area}, scope(owner, space))
      assert Ash.can?({placement, :destroy}, scope(owner, space))
    end

    test "space admin can create and manage a placement for their own user owned block" do
      %{
        admin: admin,
        admin_page: page,
        admin_user_owned_block: block,
        space: space,
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
               scope(admin, space)
             )

      assert Ash.can?({placement, :update_order}, scope(admin, space))
      assert Ash.can?({placement, :update_area}, scope(admin, space))
      assert Ash.can?({placement, :destroy}, scope(admin, space))
    end

    test "plain member can read placements but cannot manage them" do
      %{space: space, member: member, placement: placement} = access_fixture()

      assert Ash.can?({placement, :read}, scope(member, space))
      refute Ash.can?({placement, :update_order}, scope(member, space))
      refute Ash.can?({placement, :update_area}, scope(member, space))
      refute Ash.can?({placement, :destroy}, scope(member, space))
    end

    test "plain member cannot create a page placement even for their own block" do
      %{space: space, member: member, member_page: page, member_user_owned_block: block} =
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
               scope(member, space)
             )
    end

    test "space admin cannot create a placement for another user's private block" do
      %{admin: admin, admin_page: page, foreign_user_owned_block: block, space: space} =
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
               scope(admin, space)
             )
    end

    test "outsider cannot read or manage another space's placement" do
      %{space: space, outsider: outsider, placement: placement} = access_fixture()

      refute Ash.can?({placement, :read}, scope(outsider, space))
      refute Ash.can?({placement, :update_order}, scope(outsider, space))
      refute Ash.can?({placement, :update_area}, scope(outsider, space))
      refute Ash.can?({placement, :destroy}, scope(outsider, space))
    end
  end

  defp access_fixture do
    space = generate(space())
    owner = generate(user())
    admin = generate(user())
    member = generate(user())
    outsider = generate(user())
    foreign_user = generate(user())

    add_membership(space, owner, :owner)
    add_membership(space, admin, :admin)
    add_membership(space, member, :member)
    grant_active_telegram_access(space, admin)
    grant_active_telegram_access(space, member)

    owner_scope = scope(owner, space)
    {:ok, page} = Page.create(authorize?: false, scope: owner_scope)

    admin_scope = scope(admin, space)
    {:ok, admin_page} = Page.create(authorize?: false, scope: admin_scope)

    member_scope = scope(member, space)
    {:ok, member_page} = Page.create(authorize?: false, scope: member_scope)

    space_owned_block =
      create_block(
        %{data: %{"text" => "space"}, owner_space_id: space.id, type: :text},
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

    placement = create_placement(page, space_owned_block, owner_scope)

    %{
      admin: admin,
      admin_page: admin_page,
      admin_user_owned_block: admin_user_owned_block,
      foreign_user_owned_block: foreign_user_owned_block,
      space: space,
      member: member,
      member_page: member_page,
      member_user_owned_block: member_user_owned_block,
      outsider: outsider,
      owner: owner,
      placement: placement
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
        order_key: "a0",
        area: nil
      },
      action: :create,
      authorize?: false,
      domain: Wik.Blocks,
      scope: scope
    )
  end

  defp scope(actor, tenant \\ nil), do: %Scope{actor: actor, tenant: tenant}
end
