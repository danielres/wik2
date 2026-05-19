defmodule Wik.TaggingsPolicyTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.GroupUserRelation
  alias Wik.Scope
  alias Wik.Tags
  alias Wik.Tags.Tagging

  describe "membership tagging access" do
    test "group members can read, only the membership owner can manage, and superadmin bypasses" do
      %{
        admin: admin,
        group: group,
        member: member,
        member_membership: member_membership,
        other_member: other_member,
        owner: owner,
        superadmin: superadmin,
        tag: tag,
        tagging: tagging
      } = access_fixture()

      assert Ash.can?({tagging, :read}, scope(owner, group))
      assert Ash.can?({tagging, :read}, scope(admin, group))
      assert Ash.can?({tagging, :read}, scope(other_member, group))

      assert {:ok, _} =
               Tags.upsert_membership_tagging(
                 member_membership,
                 tag.id,
                 %{dimensions: %{"interest" => 4}, description: nil},
                 scope: scope(member, group)
               )

      assert {:error, _} =
               Tags.upsert_membership_tagging(
                 member_membership,
                 tag.id,
                 %{dimensions: %{"interest" => 3}, description: nil},
                 scope: scope(owner, group)
               )

      assert {:error, _} =
               Tags.upsert_membership_tagging(
                 member_membership,
                 tag.id,
                 %{dimensions: %{"interest" => 3}, description: nil},
                 scope: scope(admin, group)
               )

      assert {:error, _} =
               Tags.upsert_membership_tagging(
                 member_membership,
                 tag.id,
                 %{dimensions: %{"interest" => 3}, description: nil},
                 scope: scope(other_member, group)
               )

      assert Ash.can?({tagging, :destroy}, scope(superadmin, group))

      assert {:ok, _} =
               Ash.create(
                 Tagging,
                 %{
                   description: nil,
                   dimensions: %{"skill" => 1},
                   tag_id: tag.id,
                   tagged_by_group_user_relation_id: member_membership.id,
                   taggable_id: member_membership.id,
                   taggable_type: "group_user_relation"
                 },
                 action: :create,
                 domain: Wik.Tags,
                 scope: scope(superadmin, group)
               )
    end

    test "outsiders cannot read another group's member taggings" do
      %{group: group, outsider: outsider, tagging: tagging} = access_fixture()
      refute Ash.can?({tagging, :read}, scope(outsider, group))
    end
  end

  defp access_fixture do
    owner = generate(user())
    admin = generate(user())
    member = generate(user())
    other_member = generate(user())
    outsider = generate(user())
    superadmin = generate(user(role: :superadmin))
    group = generate(group(author: owner))

    add_membership(group, owner, :owner)
    add_membership(group, admin, :admin)
    member_membership = add_membership(group, member, :member)
    add_membership(group, other_member, :member)

    grant_active_telegram_access(group, admin)
    grant_active_telegram_access(group, member)
    grant_active_telegram_access(group, other_member)

    {:ok, tag} = Tags.create_tag("dance", "Dance", nil, scope: scope(owner, group))

    {:ok, tagging} =
      Tags.upsert_membership_tagging(
        member_membership,
        tag.id,
        %{dimensions: %{"interest" => 5}, description: nil},
        scope: scope(member, group)
      )

    %{
      admin: admin,
      group: group,
      member: member,
      member_membership: member_membership,
      other_member: other_member,
      outsider: outsider,
      owner: owner,
      superadmin: superadmin,
      tag: tag,
      tagging: tagging
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
