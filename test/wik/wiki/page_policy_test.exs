defmodule Wik.Wiki.PagePolicyTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.Membership
  alias Wik.Scope
  alias Wik.Wiki.Page

  describe "page access" do
    test "superadmin can read and manage any page" do
      %{space: space, page: page, superadmin: superadmin} = access_fixture()

      assert_allowed(superadmin, space, page)
    end

    test "owner can read and manage their space's page" do
      %{space: space, owner: owner, page: page} = access_fixture()

      assert_allowed(owner, space, page)
    end

    test "admin can read and manage their space's page" do
      %{admin: admin, space: space, page: page} = access_fixture()

      assert_allowed(admin, space, page)
    end

    test "plain member can read their space's page but cannot manage it" do
      %{space: space, member: member, page: page} = access_fixture()

      assert_read_only(member, space, page)
    end

    test "outsider cannot read or manage another space's page" do
      %{space: space, outsider: outsider, page: page} = access_fixture()

      assert_denied(outsider, space, page)
    end

    test "space admin cannot read or manage another space's page" do
      admin = generate(user())
      member_space = generate(space())
      other_space = generate(space())
      add_membership(member_space, admin, :admin)
      grant_active_telegram_access(member_space, admin)
      other_page = create_page(other_space)

      refute Ash.can?({other_page, :read}, scope(admin, member_space))
      refute Ash.can?({other_page, :update}, scope(admin, member_space))
      refute Ash.can?({other_page, :destroy}, scope(admin, member_space))

      assert {:ok, pages} = Ash.read(Page, scope: scope(admin, member_space))
      refute Enum.any?(pages, &(&1.id == other_page.id))
    end
  end

  defp assert_allowed(actor, space, page) do
    assert Ash.can?({page, :read}, scope(actor, space))
    assert Ash.can?({Page, :create}, scope(actor, space))
    assert Ash.can?({page, :update}, scope(actor, space))
    assert Ash.can?({page, :destroy}, scope(actor, space))

    assert {:ok, pages} = Ash.read(Page, scope: scope(actor, space))
    assert Enum.any?(pages, &(&1.id == page.id))
  end

  defp assert_read_only(actor, space, page) do
    assert Ash.can?({page, :read}, scope(actor, space))
    refute Ash.can?({Page, :create}, scope(actor, space))
    refute Ash.can?({page, :update}, scope(actor, space))
    refute Ash.can?({page, :destroy}, scope(actor, space))

    assert {:ok, pages} = Ash.read(Page, scope: scope(actor, space))
    assert Enum.any?(pages, &(&1.id == page.id))
  end

  defp assert_denied(actor, space, page) do
    refute Ash.can?({page, :read}, scope(actor, space))
    refute Ash.can?({Page, :create}, scope(actor, space))
    refute Ash.can?({page, :update}, scope(actor, space))
    refute Ash.can?({page, :destroy}, scope(actor, space))

    assert {:ok, pages} = Ash.read(Page, scope: scope(actor, space))
    refute Enum.any?(pages, &(&1.id == page.id))
  end

  defp access_fixture do
    space = generate(space())
    page = create_page(space)
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
      page: page,
      superadmin: superadmin
    }
  end

  defp create_page(space) do
    actor = generate(user())
    scope = scope(actor, space)

    {:ok, page} = Page.create(authorize?: false, scope: scope)
    page
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

  defp scope(actor, tenant) do
    %Scope{actor: actor, tenant: tenant}
  end
end
