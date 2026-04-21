defmodule Qblog.Wiki.PagePolicyTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Accounts.GroupUserRelation
  alias Qblog.Scope
  alias Qblog.Wiki.Page

  describe "page access" do
    test "superadmin can read and manage any page" do
      %{group: group, page: page, superadmin: superadmin} = access_fixture()

      assert_allowed(superadmin, group, page)
    end

    test "owner can read and manage their group's page" do
      %{group: group, owner: owner, page: page} = access_fixture()

      assert_allowed(owner, group, page)
    end

    test "admin can read and manage their group's page" do
      %{admin: admin, group: group, page: page} = access_fixture()

      assert_allowed(admin, group, page)
    end

    test "plain member can read their group's page but cannot manage it" do
      %{group: group, member: member, page: page} = access_fixture()

      assert_read_only(member, group, page)
    end

    test "outsider cannot read or manage another group's page" do
      %{group: group, outsider: outsider, page: page} = access_fixture()

      assert_denied(outsider, group, page)
    end

    test "group admin cannot read or manage another group's page" do
      admin = generate(user())
      member_group = generate(group())
      other_group = generate(group())
      add_membership(member_group, admin, :admin)
      grant_active_telegram_access(member_group, admin)
      other_page = create_page(other_group)

      refute Ash.can?({other_page, :read}, scope(admin, member_group))
      refute Ash.can?({other_page, :update}, scope(admin, member_group))
      refute Ash.can?({other_page, :destroy}, scope(admin, member_group))

      assert {:ok, pages} = Ash.read(Page, scope: scope(admin, member_group))
      refute Enum.any?(pages, &(&1.id == other_page.id))
    end
  end

  defp assert_allowed(actor, group, page) do
    assert Ash.can?({page, :read}, scope(actor, group))
    assert Ash.can?({Page, :create}, scope(actor, group))
    assert Ash.can?({page, :update}, scope(actor, group))
    assert Ash.can?({page, :destroy}, scope(actor, group))

    assert {:ok, pages} = Ash.read(Page, scope: scope(actor, group))
    assert Enum.any?(pages, &(&1.id == page.id))
  end

  defp assert_read_only(actor, group, page) do
    assert Ash.can?({page, :read}, scope(actor, group))
    refute Ash.can?({Page, :create}, scope(actor, group))
    refute Ash.can?({page, :update}, scope(actor, group))
    refute Ash.can?({page, :destroy}, scope(actor, group))

    assert {:ok, pages} = Ash.read(Page, scope: scope(actor, group))
    assert Enum.any?(pages, &(&1.id == page.id))
  end

  defp assert_denied(actor, group, page) do
    refute Ash.can?({page, :read}, scope(actor, group))
    refute Ash.can?({Page, :create}, scope(actor, group))
    refute Ash.can?({page, :update}, scope(actor, group))
    refute Ash.can?({page, :destroy}, scope(actor, group))

    assert {:ok, pages} = Ash.read(Page, scope: scope(actor, group))
    refute Enum.any?(pages, &(&1.id == page.id))
  end

  defp access_fixture do
    group = generate(group())
    page = create_page(group)
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
      page: page,
      superadmin: superadmin
    }
  end

  defp create_page(group) do
    actor = generate(user())
    scope = scope(actor, group)

    {:ok, page} = Page.create(authorize?: false, scope: scope)
    page
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

  defp scope(actor, tenant) do
    %Scope{actor: actor, tenant: tenant}
  end
end
