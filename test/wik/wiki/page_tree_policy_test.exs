defmodule Wik.Wiki.PageTreePolicyTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.Membership
  alias Wik.Scope
  alias Wik.Wiki.PageTree

  describe "page tree access" do
    test "superadmin can read and manage any page tree" do
      %{space: space, page_tree: page_tree, superadmin: superadmin} = access_fixture()

      assert_allowed(superadmin, space, page_tree)
    end

    test "owner can read and manage their space's page tree" do
      %{space: space, owner: owner, page_tree: page_tree} = access_fixture()

      assert_allowed(owner, space, page_tree)
    end

    test "admin can read and manage their space's page tree" do
      %{admin: admin, space: space, page_tree: page_tree} = access_fixture()

      assert_allowed(admin, space, page_tree)
    end

    test "plain member can read their space's page tree but cannot manage it" do
      %{space: space, member: member, page_tree: page_tree} = access_fixture()

      assert_infrastructure_only(member, space, page_tree)
    end

    test "outsider cannot read or manage another space's page tree" do
      %{space: space, outsider: outsider, page_tree: page_tree} = access_fixture()

      assert_denied(outsider, space, page_tree)
    end

    test "space admin cannot read or manage another space's page tree" do
      admin = generate(user())
      member_space = generate(space())
      other_space = generate(space())
      add_membership(member_space, admin, :admin)
      grant_active_telegram_access(member_space, admin)
      other_page_tree = generate(page_tree(space: other_space, nodes: base_nodes()))

      refute Ash.can?({other_page_tree, :read}, scope(admin, member_space))
      refute Ash.can?({other_page_tree, :manage_tree}, scope(admin, member_space))
      refute Ash.can?({other_page_tree, :add_child}, scope(admin, member_space))
      refute Ash.can?({other_page_tree, :move_node}, scope(admin, member_space))
      refute Ash.can?({other_page_tree, :destroy_node}, scope(admin, member_space))

      assert {:ok, page_trees} = Ash.read(PageTree, scope: scope(admin, member_space))
      refute Enum.any?(page_trees, &(&1.id == other_page_tree.id))
    end
  end

  defp assert_allowed(actor, space, page_tree) do
    assert Ash.can?({page_tree, :read}, scope(actor, space))
    assert Ash.can?({PageTree, :create}, scope(actor, space))
    assert Ash.can?({PageTree, :ensure}, scope(actor, space))
    assert Ash.can?({page_tree, :manage_tree}, scope(actor, space))
    assert Ash.can?({page_tree, :add_child}, scope(actor, space))
    assert Ash.can?({page_tree, :move_node}, scope(actor, space))
    assert Ash.can?({page_tree, :destroy_node}, scope(actor, space))

    assert {:ok, page_trees} = Ash.read(PageTree, scope: scope(actor, space))
    assert Enum.any?(page_trees, &(&1.id == page_tree.id))
  end

  defp assert_denied(actor, space, page_tree) do
    refute Ash.can?({page_tree, :read}, scope(actor, space))
    assert_denied_management(actor, space, page_tree)

    assert {:ok, page_trees} = Ash.read(PageTree, scope: scope(actor, space))
    refute Enum.any?(page_trees, &(&1.id == page_tree.id))
  end

  defp assert_infrastructure_only(actor, space, page_tree) do
    assert Ash.can?({page_tree, :read}, scope(actor, space))
    assert Ash.can?({PageTree, :create}, scope(actor, space))
    assert Ash.can?({PageTree, :ensure}, scope(actor, space))
    assert_denied_management(actor, space, page_tree)

    assert {:ok, page_trees} = Ash.read(PageTree, scope: scope(actor, space))
    assert Enum.any?(page_trees, &(&1.id == page_tree.id))
  end

  defp assert_denied_management(actor, space, page_tree) do
    refute Ash.can?({page_tree, :manage_tree}, scope(actor, space))
    refute Ash.can?({page_tree, :add_child}, scope(actor, space))
    refute Ash.can?({page_tree, :move_node}, scope(actor, space))
    refute Ash.can?({page_tree, :destroy_node}, scope(actor, space))
  end

  defp access_fixture do
    space = generate(space())
    page_tree = generate(page_tree(space: space, nodes: base_nodes()))
    owner = generate(user())
    admin = generate(user())
    member = generate(user())
    outsider = generate(user())
    superadmin = generate(user(role: :superadmin))

    add_membership(space, owner, :owner)
    add_membership(space, admin, :admin)
    add_membership(space, member, :member)
    grant_active_telegram_access(space, admin)
    grant_active_telegram_access(space, member)

    %{
      admin: admin,
      space: space,
      member: member,
      outsider: outsider,
      owner: owner,
      page_tree: page_tree,
      superadmin: superadmin
    }
  end

  defp add_membership(space, user, type) do
    {:ok, membership} =
      Ash.create(
        Membership,
        %{space_id: space.id, type: type, user_id: user.id},
        authorize?: false,
        domain: Wik.Accounts
      )

    membership
  end

  defp base_nodes do
    [
      %{id: 1, page_id: nil, parent_id: nil, slug: "home", title: "Home"},
      %{id: 2, page_id: nil, parent_id: nil, slug: "docs", title: "Docs"}
    ]
  end

  defp scope(actor, tenant) do
    %Scope{actor: actor, tenant: tenant}
  end
end
