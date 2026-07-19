defmodule Wik.TagsPolicyTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.Membership
  alias Wik.Scope
  alias Wik.Tags
  alias Wik.Tags.Tag
  alias Wik.Tags.TagEdge

  describe "tag graph access" do
    test "superadmin can read and manage any accessible tag graph resource" do
      %{edge: edge, space: space, superadmin: superadmin, tag: tag} = access_fixture()

      assert Ash.can?({tag, :read}, scope(superadmin, space))
      assert Ash.can?({Tag, :create}, scope(superadmin, space))
      assert Ash.can?({tag, :update}, scope(superadmin, space))
      assert Ash.can?({tag, :destroy}, scope(superadmin, space))
      assert Ash.can?({edge, :read}, scope(superadmin, space))
      assert Ash.can?({TagEdge, :create}, scope(superadmin, space))
      assert Ash.can?({edge, :destroy}, scope(superadmin, space))
    end

    test "owner and admin can manage tags and edges" do
      %{admin: admin, edge: edge, space: space, owner: owner, tag: tag} = access_fixture()

      for actor <- [owner, admin] do
        assert Ash.can?({tag, :read}, scope(actor, space))
        assert Ash.can?({Tag, :create}, scope(actor, space))
        assert Ash.can?({tag, :update}, scope(actor, space))
        assert Ash.can?({tag, :destroy}, scope(actor, space))
        assert Ash.can?({edge, :read}, scope(actor, space))
        assert Ash.can?({TagEdge, :create}, scope(actor, space))
        assert Ash.can?({edge, :destroy}, scope(actor, space))
      end
    end

    test "member can read but not manage, and outsider cannot access the graph" do
      %{edge: edge, space: space, member: member, outsider: outsider, tag: tag} = access_fixture()

      assert Ash.can?({tag, :read}, scope(member, space))
      refute Ash.can?({Tag, :create}, scope(member, space))
      refute Ash.can?({tag, :update}, scope(member, space))
      refute Ash.can?({tag, :destroy}, scope(member, space))
      assert Ash.can?({edge, :read}, scope(member, space))
      refute Ash.can?({TagEdge, :create}, scope(member, space))
      refute Ash.can?({edge, :destroy}, scope(member, space))

      refute Ash.can?({tag, :read}, scope(outsider, space))
      refute Ash.can?({Tag, :create}, scope(outsider, space))
      refute Ash.can?({edge, :read}, scope(outsider, space))
    end
  end

  defp access_fixture do
    owner = generate(user())
    admin = generate(user())
    member = generate(user())
    outsider = generate(user())
    superadmin = generate(user(role: :superadmin))
    space = generate(space(author: owner))

    add_membership(space, owner, :owner)
    add_membership(space, admin, :admin)
    add_membership(space, member, :member)
    grant_active_telegram_access(space, admin)
    grant_active_telegram_access(space, member)

    {:ok, tag} = Tags.create_tag("dance", "Dance", scope: scope(owner, space))

    {:ok, child} =
      Tags.create_tag("partner-dance", "Partner dance", scope: scope(owner, space))

    {:ok, edge} = Tags.link_tags(tag.id, child.id, scope: scope(owner, space))

    %{
      admin: admin,
      edge: edge,
      space: space,
      member: member,
      outsider: outsider,
      owner: owner,
      superadmin: superadmin,
      tag: tag
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

  defp scope(actor, tenant), do: %Scope{actor: actor, tenant: tenant}
end
