defmodule Wik.TaggingsTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.GroupUserRelation
  alias Wik.Scope
  alias Wik.Tags
  alias Wik.Tags.Tagging

  require Ash.Query

  describe "membership taggings" do
    test "stores one row per self-authored membership tagging and normalizes zero dimensions and blank description" do
      %{group: group, membership: membership, owner: owner, user: user} = member_fixture()
      scope = scope(user, group)

      {:ok, dance} = Tags.create_tag("dance", "Dance", nil, scope: scope(owner, group))

      assert {:ok, _tagging} =
               Tags.upsert_membership_tagging(
                 membership,
                 dance.id,
                 %{dimensions: %{interest: 10, skill: 0}, description: "   "},
                 scope: scope
               )

      assert {:ok, taggings} = Tags.list_membership_taggings(membership, scope: scope)

      assert Enum.map(taggings, &{&1.dimensions, &1.description, &1.tag_id}) == [
               {%{"interest" => 10}, nil, dance.id}
             ]
    end

    test "upsert semantics replace the existing row for the same group, target, author, and tag" do
      %{group: group, membership: membership, owner: owner, user: user} = member_fixture()
      owner_scope = scope(owner, group)
      member_scope = scope(user, group)

      {:ok, dance} = Tags.create_tag("dance", "Dance", nil, scope: owner_scope)

      assert {:ok, first_tagging} =
               Tags.upsert_membership_tagging(
                 membership,
                 dance.id,
                 %{dimensions: %{"interest" => 2}, description: "first"},
                 scope: member_scope
               )

      assert {:ok, second_tagging} =
               Tags.upsert_membership_tagging(
                 membership,
                 dance.id,
                 %{dimensions: %{"interest" => 4, "skill" => 1}, description: "updated"},
                 scope: member_scope
               )

      assert first_tagging.id == second_tagging.id

      assert {:ok, [tagging]} = Tags.list_membership_taggings(membership, scope: member_scope)
      assert tagging.dimensions == %{"interest" => 4, "skill" => 1}
      assert tagging.description == "updated"
    end

    test "rejects unknown dimension keys, non-integer values, and out-of-range values" do
      %{group: group, membership: membership, owner: owner, user: user} = member_fixture()
      owner_scope = scope(owner, group)
      member_scope = scope(user, group)

      {:ok, dance} = Tags.create_tag("dance", "Dance", nil, scope: owner_scope)

      assert {:error, _error} =
               Tags.upsert_membership_tagging(
                 membership,
                 dance.id,
                 %{dimensions: %{"curiosity" => 3}, description: nil},
                 scope: member_scope
               )

      assert {:error, _error} =
               Tags.upsert_membership_tagging(
                 membership,
                 dance.id,
                 %{dimensions: %{"interest" => "3"}, description: nil},
                 scope: member_scope
               )

      assert {:error, _error} =
               Tags.upsert_membership_tagging(
                 membership,
                 dance.id,
                 %{dimensions: %{"skill" => 11}, description: nil},
                 scope: member_scope
               )
    end

    test "rejects empty dimensions after normalization" do
      %{group: group, membership: membership, owner: owner, user: user} = member_fixture()
      owner_scope = scope(owner, group)
      member_scope = scope(user, group)

      {:ok, dance} = Tags.create_tag("dance", "Dance", nil, scope: owner_scope)

      assert {:error, _error} =
               Tags.upsert_membership_tagging(
                 membership,
                 dance.id,
                 %{dimensions: %{"interest" => 0, "skill" => 0}, description: "only text"},
                 scope: member_scope
               )
    end

    test "rejects duplicate direct rows, cross-group mismatches, unsupported targets, and deletes with tag or membership removal" do
      %{group: group, membership: membership, owner: owner, user: user} = member_fixture()
      scope = scope(user, group)
      owner_scope = scope(owner, group)
      other_group = generate(group(author: owner))
      other_membership = add_membership(other_group, user, :member)
      grant_active_telegram_access(other_group, user)

      {:ok, dance} = Tags.create_tag("dance", "Dance", nil, scope: owner_scope)

      {:ok, _} =
        Tags.upsert_membership_tagging(
          membership,
          dance.id,
          %{dimensions: %{"interest" => 10}, description: nil},
          scope: scope
        )

      attrs = %{
        description: nil,
        dimensions: %{"interest" => 10},
        tag_id: dance.id,
        tagged_by_group_user_relation_id: membership.id,
        taggable_id: membership.id,
        taggable_type: "group_user_relation"
      }

      assert {:error, _error} =
               Ash.create(Tagging, attrs, action: :create, domain: Wik.Tags, scope: scope)

      assert {:error, _error} =
               Ash.create(
                 Tagging,
                 %{attrs | taggable_id: other_membership.id},
                 action: :create,
                 domain: Wik.Tags,
                 scope: scope
               )

      assert {:error, _error} =
               Ash.create(
                 Tagging,
                 %{attrs | taggable_type: "block"},
                 action: :create,
                 domain: Wik.Tags,
                 scope: scope
               )

      assert {:ok, _tag} = Tags.destroy_tag(dance.id, scope: owner_scope)
      assert {:ok, []} = Tags.list_membership_taggings(membership, scope: scope)

      {:ok, dance} = Tags.create_tag("dance", "Dance", nil, scope: owner_scope)

      assert {:ok, _} =
               Tags.upsert_membership_tagging(
                 membership,
                 dance.id,
                 %{dimensions: %{"interest" => 2}, description: nil},
                 scope: scope
               )

      assert Ash.destroy(membership, authorize?: false, domain: Wik.Accounts) in [
               :ok,
               {:ok, membership}
             ]

      query =
        Tagging
        |> Ash.Query.filter(
          taggable_type == "group_user_relation" and taggable_id == ^membership.id
        )

      refute Ash.exists?(query, authorize?: false, domain: Wik.Tags, scope: scope)
    end
  end

  defp member_fixture do
    owner = generate(user())
    user = generate(user())
    group = generate(group(author: owner))
    add_membership(group, owner, :owner)
    membership = add_membership(group, user, :member)
    grant_active_telegram_access(group, user)
    %{group: group, membership: membership, owner: owner, user: user}
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
