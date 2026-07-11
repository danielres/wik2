defmodule Wik.TaggingsPolicyTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.Membership
  alias Wik.Scope
  alias Wik.Tags
  alias Wik.Tags.Tagging

  describe "membership tagging access" do
    test "space members can read, only the membership owner can manage, and superadmin bypasses" do
      %{
        admin: admin,
        space: space,
        member: member,
        member_membership: member_membership,
        other_member: other_member,
        owner: owner,
        superadmin: superadmin,
        tag: tag,
        other_tag: other_tag,
        tagging: tagging
      } = access_fixture()

      assert Ash.can?({tagging, :read}, scope(owner, space))
      assert Ash.can?({tagging, :read}, scope(admin, space))
      assert Ash.can?({tagging, :read}, scope(other_member, space))

      assert {:ok, _} =
               Tags.upsert_tagging(
                 member_membership,
                 member_membership,
                 tag.id,
                 %{dimensions: %{"interest" => 4}, description: nil},
                 scope: scope(member, space)
               )

      assert {:error, _} =
               Tags.upsert_tagging(
                 member_membership,
                 member_membership,
                 tag.id,
                 %{dimensions: %{"interest" => 3}, description: nil},
                 scope: scope(owner, space)
               )

      assert {:error, _} =
               Tags.upsert_tagging(
                 member_membership,
                 member_membership,
                 tag.id,
                 %{dimensions: %{"interest" => 3}, description: nil},
                 scope: scope(admin, space)
               )

      assert {:error, _} =
               Tags.upsert_tagging(
                 member_membership,
                 member_membership,
                 tag.id,
                 %{dimensions: %{"interest" => 3}, description: nil},
                 scope: scope(other_member, space)
               )

      assert Ash.can?({tagging, :destroy}, scope(superadmin, space))

      assert {:ok, _} =
               Tags.upsert_tagging(
                 member_membership,
                 member_membership,
                 tag.id,
                 %{dimensions: %{"interest" => 3}, description: nil},
                 scope: scope(superadmin, space)
               )

      assert {:ok, _} =
               Ash.create(
                 Tagging,
                 %{
                   description: nil,
                   dimensions: %{"skill" => 1},
                   tag_id: other_tag.id,
                   tagged_by_membership_id: member_membership.id,
                   taggable_id: member_membership.id,
                   taggable_type: "membership"
                 },
                 action: :create,
                 domain: Wik.Tags,
                 scope: scope(superadmin, space)
               )
    end

    test "outsiders cannot read another space's member taggings" do
      %{space: space, outsider: outsider, tagging: tagging} = access_fixture()
      refute Ash.can?({tagging, :read}, scope(outsider, space))
    end
  end

  defp access_fixture do
    owner = generate(user())
    admin = generate(user())
    member = generate(user())
    other_member = generate(user())
    outsider = generate(user())
    superadmin = generate(user(role: :superadmin))
    space = generate(space(author: owner))

    add_membership(space, owner, :owner)
    add_membership(space, admin, :admin)
    member_membership = add_membership(space, member, :member)
    add_membership(space, other_member, :member)

    grant_active_telegram_access(space, admin)
    grant_active_telegram_access(space, member)
    grant_active_telegram_access(space, other_member)

    {:ok, tag} = Tags.create_tag("dance", "Dance", nil, scope: scope(owner, space))
    {:ok, other_tag} = Tags.create_tag("music", "Music", nil, scope: scope(owner, space))

    {:ok, tagging} =
      Tags.upsert_tagging(
        member_membership,
        member_membership,
        tag.id,
        %{dimensions: %{"interest" => 5}, description: nil},
        scope: scope(member, space)
      )

    %{
      admin: admin,
      space: space,
      member: member,
      member_membership: member_membership,
      other_member: other_member,
      outsider: outsider,
      owner: owner,
      other_tag: other_tag,
      superadmin: superadmin,
      tag: tag,
      tagging: tagging
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
