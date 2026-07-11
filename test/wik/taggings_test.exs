defmodule Wik.TaggingsTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.Membership
  alias Wik.Scope
  alias Wik.Tags
  alias Wik.Tags.Tagging

  require Ash.Query

  describe "membership taggings" do
    test "stores one row per self-authored membership tagging and normalizes zero dimensions and blank description" do
      %{space: space, membership: membership, owner: owner, user: user} = member_fixture()

      scope = scope(user, space)

      {:ok, dance} = Tags.create_tag("dance", "Dance", nil, scope: scope(owner, space))

      assert {:ok, _tagging} =
               Tags.upsert_tagging(
                 membership,
                 membership,
                 dance.id,
                 %{dimensions: %{interest: 10, skill: 0}, description: "   "},
                 scope: scope
               )

      assert {:ok, taggings} = Tags.list_taggings(membership, scope: scope)

      assert Enum.map(taggings, &{&1.dimensions, &1.description, &1.tag_id}) == [
               {%{"interest" => 10}, nil, dance.id}
             ]
    end

    test "upsert semantics replace the existing row for the same space, target, author, and tag" do
      %{space: space, membership: membership, owner: owner, user: user} = member_fixture()

      owner_scope = scope(owner, space)
      member_scope = scope(user, space)

      {:ok, dance} = Tags.create_tag("dance", "Dance", nil, scope: owner_scope)

      assert {:ok, first_tagging} =
               Tags.upsert_tagging(
                 membership,
                 membership,
                 dance.id,
                 %{dimensions: %{"interest" => 2}, description: "first"},
                 scope: member_scope
               )

      assert {:ok, second_tagging} =
               Tags.upsert_tagging(
                 membership,
                 membership,
                 dance.id,
                 %{dimensions: %{"interest" => 4, "skill" => 1}, description: "updated"},
                 scope: member_scope
               )

      assert first_tagging.id == second_tagging.id

      assert {:ok, [tagging]} = Tags.list_taggings(membership, scope: member_scope)
      assert tagging.dimensions == %{"interest" => 4, "skill" => 1}
      assert tagging.description == "updated"
    end

    test "rejects unknown dimension keys, non-integer values, and out-of-range values" do
      %{space: space, membership: membership, owner: owner, user: user} = member_fixture()

      owner_scope = scope(owner, space)
      member_scope = scope(user, space)

      {:ok, dance} = Tags.create_tag("dance", "Dance", nil, scope: owner_scope)

      assert {:error, _error} =
               Tags.upsert_tagging(
                 membership,
                 membership,
                 dance.id,
                 %{dimensions: %{"curiosity" => 3}, description: nil},
                 scope: member_scope
               )

      assert {:error, _error} =
               Tags.upsert_tagging(
                 membership,
                 membership,
                 dance.id,
                 %{dimensions: %{"interest" => "3"}, description: nil},
                 scope: member_scope
               )

      assert {:error, _error} =
               Tags.upsert_tagging(
                 membership,
                 membership,
                 dance.id,
                 %{dimensions: %{"skill" => 11}, description: nil},
                 scope: member_scope
               )
    end

    test "rejects empty dimensions after normalization" do
      %{space: space, membership: membership, owner: owner, user: user} = member_fixture()
      owner_scope = scope(owner, space)
      member_scope = scope(user, space)

      {:ok, dance} = Tags.create_tag("dance", "Dance", nil, scope: owner_scope)

      assert {:error, _error} =
               Tags.upsert_tagging(
                 membership,
                 membership,
                 dance.id,
                 %{dimensions: %{"interest" => 0, "skill" => 0}, description: "only text"},
                 scope: member_scope
               )
    end

    test "rejects duplicate direct rows, cross-space mismatches, unsupported targets, and deletes with tag or membership removal" do
      %{space: space, membership: membership, owner: owner, user: user} = member_fixture()
      scope = scope(user, space)
      owner_scope = scope(owner, space)
      other_space = generate(space(author: owner))
      other_membership = add_membership(other_space, user, :member)
      grant_active_telegram_access(other_space, user)

      {:ok, dance} = Tags.create_tag("dance", "Dance", nil, scope: owner_scope)

      {:ok, _} =
        Tags.upsert_tagging(
          membership,
          membership,
          dance.id,
          %{dimensions: %{"interest" => 10}, description: nil},
          scope: scope
        )

      attrs = %{
        description: nil,
        dimensions: %{"interest" => 10},
        tag_id: dance.id,
        tagged_by_membership_id: membership.id,
        taggable_id: membership.id,
        taggable_type: "membership"
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
      assert {:ok, []} = Tags.list_taggings(membership, scope: scope)

      {:ok, dance} = Tags.create_tag("dance", "Dance", nil, scope: owner_scope)

      assert {:ok, _} =
               Tags.upsert_tagging(
                 membership,
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
        |> Ash.Query.filter(taggable_type == "membership" and taggable_id == ^membership.id)

      refute Ash.exists?(query, authorize?: false, domain: Wik.Tags, scope: scope)
    end
  end

  describe "page taggings" do
    test "stores one row per member, page, and tag and normalizes relevancy" do
      assert_page_taggings_work()
    end
  end

  defp assert_page_taggings_work do
    %{
      owner_membership: owner_membership,
      space: space,
      membership: membership,
      owner: owner,
      user: user
    } =
      member_fixture()

    owner_scope = scope(owner, space)
    member_scope = scope(user, space)

    {:ok, page} = Wik.Wiki.Page.create(scope: owner_scope)
    {:ok, dance} = Tags.create_tag("dance", "Dance", nil, scope: owner_scope)

    assert {:error, _error} =
             Tags.upsert_tagging(
               page,
               membership,
               dance.id,
               %{dimensions: %{"interest" => 4}},
               scope: member_scope
             )

    assert {:ok, first_tagging} =
             Tags.upsert_tagging(
               page,
               owner_membership,
               dance.id,
               %{dimensions: %{"relevancy" => 4}},
               scope: owner_scope
             )

    assert {:ok, second_tagging} =
             Tags.upsert_tagging(
               page,
               owner_membership,
               dance.id,
               %{dimensions: %{"relevancy" => 8}},
               scope: owner_scope
             )

    assert first_tagging.id == second_tagging.id

    assert {:ok, [tagging]} = Tags.list_taggings(page, scope: owner_scope)
    assert tagging.dimensions == %{"relevancy" => 8}
    assert tagging.tag_id == dance.id
    assert tagging.tagged_by_membership_id == owner_membership.id
  end

  defp member_fixture do
    owner = generate(user())
    user = generate(user())
    space = generate(space(author: owner))
    owner_membership = add_membership(space, owner, :owner)
    membership = add_membership(space, user, :member)
    grant_active_telegram_access(space, user)

    %{
      space: space,
      membership: membership,
      owner: owner,
      owner_membership: owner_membership,
      user: user
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
