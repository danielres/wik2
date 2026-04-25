defmodule Qblog.Wiki.PageTreePolicyTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Accounts.GroupUserRelation
  alias Qblog.Scope
  alias Qblog.Wiki.PageTree

  describe "page tree access" do
    test "superadmin can read and manage any page tree" do
      %{group: group, page_tree: page_tree, superadmin: superadmin} = access_fixture()

      assert_allowed(superadmin, group, page_tree)
    end

    test "owner can read and manage their group's page tree" do
      %{group: group, owner: owner, page_tree: page_tree} = access_fixture()

      assert_allowed(owner, group, page_tree)
    end

    test "admin can read and manage their group's page tree" do
      %{admin: admin, group: group, page_tree: page_tree} = access_fixture()

      assert_allowed(admin, group, page_tree)
    end

    test "plain member can read their group's page tree but cannot manage it" do
      %{group: group, member: member, page_tree: page_tree} = access_fixture()

      assert_infrastructure_only(member, group, page_tree)
    end

    test "outsider cannot read or manage another group's page tree" do
      %{group: group, outsider: outsider, page_tree: page_tree} = access_fixture()

      assert_denied(outsider, group, page_tree)
    end

    test "group admin cannot read or manage another group's page tree" do
      admin = generate(user())
      member_group = generate(group())
      other_group = generate(group())
      add_membership(member_group, admin, :admin)
      grant_active_telegram_access(member_group, admin)
      other_page_tree = generate(page_tree(group: other_group, nodes: base_nodes()))

      refute Ash.can?({other_page_tree, :read}, scope(admin, member_group))
      refute Ash.can?({other_page_tree, :manage_tree}, scope(admin, member_group))
      refute Ash.can?({other_page_tree, :add_child}, scope(admin, member_group))
      refute Ash.can?({other_page_tree, :move_node}, scope(admin, member_group))
      refute Ash.can?({other_page_tree, :destroy_node}, scope(admin, member_group))

      assert {:ok, page_trees} = Ash.read(PageTree, scope: scope(admin, member_group))
      refute Enum.any?(page_trees, &(&1.id == other_page_tree.id))
    end
  end

  defp assert_allowed(actor, group, page_tree) do
    assert Ash.can?({page_tree, :read}, scope(actor, group))
    assert Ash.can?({PageTree, :create}, scope(actor, group))
    assert Ash.can?({PageTree, :ensure}, scope(actor, group))
    assert Ash.can?({page_tree, :manage_tree}, scope(actor, group))
    assert Ash.can?({page_tree, :add_child}, scope(actor, group))
    assert Ash.can?({page_tree, :move_node}, scope(actor, group))
    assert Ash.can?({page_tree, :destroy_node}, scope(actor, group))

    assert {:ok, page_trees} = Ash.read(PageTree, scope: scope(actor, group))
    assert Enum.any?(page_trees, &(&1.id == page_tree.id))
  end

  defp assert_denied(actor, group, page_tree) do
    refute Ash.can?({page_tree, :read}, scope(actor, group))
    assert_denied_management(actor, group, page_tree)

    assert {:ok, page_trees} = Ash.read(PageTree, scope: scope(actor, group))
    refute Enum.any?(page_trees, &(&1.id == page_tree.id))
  end

  defp assert_infrastructure_only(actor, group, page_tree) do
    assert Ash.can?({page_tree, :read}, scope(actor, group))
    assert Ash.can?({PageTree, :create}, scope(actor, group))
    assert Ash.can?({PageTree, :ensure}, scope(actor, group))
    assert_denied_management(actor, group, page_tree)

    assert {:ok, page_trees} = Ash.read(PageTree, scope: scope(actor, group))
    assert Enum.any?(page_trees, &(&1.id == page_tree.id))
  end

  defp assert_denied_management(actor, group, page_tree) do
    refute Ash.can?({page_tree, :manage_tree}, scope(actor, group))
    refute Ash.can?({page_tree, :add_child}, scope(actor, group))
    refute Ash.can?({page_tree, :move_node}, scope(actor, group))
    refute Ash.can?({page_tree, :destroy_node}, scope(actor, group))
  end

  defp access_fixture do
    group = generate(group())
    page_tree = generate(page_tree(group: group, nodes: base_nodes()))
    owner = generate(user())
    admin = generate(user())
    member = generate(user())
    outsider = generate(user())
    superadmin = generate(user(role: :superadmin))

    add_membership(group, owner, :owner)
    add_membership(group, admin, :admin)
    add_membership(group, member, :member)
    grant_active_telegram_access(group, admin)
    grant_active_telegram_access(group, member)

    %{
      admin: admin,
      group: group,
      member: member,
      outsider: outsider,
      owner: owner,
      page_tree: page_tree,
      superadmin: superadmin
    }
  end

  defp add_membership(group, user, type) do
    {:ok, membership} =
      Ash.create(
        GroupUserRelation,
        %{group_id: group.id, type: type, user_id: user.id},
        authorize?: false,
        domain: Qblog.Accounts
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
