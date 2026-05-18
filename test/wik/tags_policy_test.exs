defmodule Wik.TagsPolicyTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.GroupUserRelation
  alias Wik.Scope
  alias Wik.Tags
  alias Wik.Tags.Tag
  alias Wik.Tags.TagEdge

  describe "tag graph access" do
    test "superadmin can read and manage any accessible tag graph resource" do
      %{edge: edge, group: group, superadmin: superadmin, tag: tag} = access_fixture()

      assert Ash.can?({tag, :read}, scope(superadmin, group))
      assert Ash.can?({Tag, :create}, scope(superadmin, group))
      assert Ash.can?({tag, :update}, scope(superadmin, group))
      assert Ash.can?({tag, :destroy}, scope(superadmin, group))
      assert Ash.can?({edge, :read}, scope(superadmin, group))
      assert Ash.can?({TagEdge, :create}, scope(superadmin, group))
      assert Ash.can?({edge, :destroy}, scope(superadmin, group))
    end

    test "owner and admin can manage tags and edges" do
      %{admin: admin, edge: edge, group: group, owner: owner, tag: tag} = access_fixture()

      for actor <- [owner, admin] do
        assert Ash.can?({tag, :read}, scope(actor, group))
        assert Ash.can?({Tag, :create}, scope(actor, group))
        assert Ash.can?({tag, :update}, scope(actor, group))
        assert Ash.can?({tag, :destroy}, scope(actor, group))
        assert Ash.can?({edge, :read}, scope(actor, group))
        assert Ash.can?({TagEdge, :create}, scope(actor, group))
        assert Ash.can?({edge, :destroy}, scope(actor, group))
      end
    end

    test "member can read but not manage, and outsider cannot access the graph" do
      %{edge: edge, group: group, member: member, outsider: outsider, tag: tag} = access_fixture()

      assert Ash.can?({tag, :read}, scope(member, group))
      refute Ash.can?({Tag, :create}, scope(member, group))
      refute Ash.can?({tag, :update}, scope(member, group))
      refute Ash.can?({tag, :destroy}, scope(member, group))
      assert Ash.can?({edge, :read}, scope(member, group))
      refute Ash.can?({TagEdge, :create}, scope(member, group))
      refute Ash.can?({edge, :destroy}, scope(member, group))

      refute Ash.can?({tag, :read}, scope(outsider, group))
      refute Ash.can?({Tag, :create}, scope(outsider, group))
      refute Ash.can?({edge, :read}, scope(outsider, group))
    end
  end

  defp access_fixture do
    owner = generate(user())
    admin = generate(user())
    member = generate(user())
    outsider = generate(user())
    superadmin = generate(user(role: :superadmin))
    group = generate(group(author: owner))

    add_membership(group, owner, :owner)
    add_membership(group, admin, :admin)
    add_membership(group, member, :member)
    grant_active_telegram_access(group, admin)
    grant_active_telegram_access(group, member)

    {:ok, tag} = Tags.create_tag("dance", "Dance", nil, scope: scope(owner, group))

    {:ok, child} =
      Tags.create_tag("partner-dance", "Partner dance", nil, scope: scope(owner, group))

    {:ok, edge} = Tags.link_tags(tag.id, child.id, scope: scope(owner, group))

    %{
      admin: admin,
      edge: edge,
      group: group,
      member: member,
      outsider: outsider,
      owner: owner,
      superadmin: superadmin,
      tag: tag
    }
  end

  defp add_membership(group, user, type) do
    Ash.create!(
      GroupUserRelation,
      %{group_id: group.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
  end

  defp scope(actor, tenant), do: %Scope{actor: actor, tenant: tenant}
end
