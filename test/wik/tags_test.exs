defmodule Wik.TagsTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.GroupUserRelation
  alias Wik.Scope
  alias Wik.Tags
  alias Wik.Tags.Tag
  alias Wik.Tags.TagEdge

  describe "tag management" do
    test "creates a tag within the current group and loads it by slug" do
      %{group: group, owner: owner} = owner_fixture()

      assert {:ok, tag} =
               Tags.create_tag("partner-dance", "Partner dance", "Moves together",
                 scope: scope(owner, group)
               )

      assert tag.group_id == group.id

      assert {:ok, loaded_tag} = Tags.get_tag_by_slug("partner-dance", scope: scope(owner, group))
      assert loaded_tag.id == tag.id
    end

    test "rejects duplicate slugs within the same group" do
      %{group: group, owner: owner} = owner_fixture()

      assert {:ok, _tag} =
               Tags.create_tag("partner-dance", "Partner dance", nil, scope: scope(owner, group))

      assert {:error, _error} =
               Tags.create_tag("partner-dance", "Partner dance again", nil,
                 scope: scope(owner, group)
               )
    end

    test "links tags within the same group and rejects duplicate, self, cross-group, and cycle edges" do
      %{group: group, owner: owner} = owner_fixture()
      other_group = generate(group())
      other_owner = generate(user())
      add_membership(other_group, other_owner, :owner)

      {:ok, root} = Tags.create_tag("dance", "Dance", nil, scope: scope(owner, group))

      {:ok, child} =
        Tags.create_tag("partner-dance", "Partner dance", nil, scope: scope(owner, group))

      {:ok, grandchild} = Tags.create_tag("tango", "Tango", nil, scope: scope(owner, group))

      {:ok, outsider_tag} =
        Tags.create_tag("other", "Other", nil, scope: scope(other_owner, other_group))

      assert {:ok, _edge} = Tags.link_tags(root.id, child.id, scope: scope(owner, group))
      assert {:ok, _edge} = Tags.link_tags(child.id, grandchild.id, scope: scope(owner, group))

      assert {:error, _error} = Tags.link_tags(root.id, child.id, scope: scope(owner, group))
      assert {:error, _error} = Tags.link_tags(root.id, root.id, scope: scope(owner, group))

      assert {:error, _error} =
               Tags.link_tags(root.id, outsider_tag.id, scope: scope(owner, group))

      assert {:error, _error} = Tags.link_tags(grandchild.id, root.id, scope: scope(owner, group))
    end

    test "destroying a tag removes incident edges and unlinking preserves both tags" do
      %{group: group, owner: owner} = owner_fixture()
      scope = scope(owner, group)

      {:ok, root} = Tags.create_tag("dance", "Dance", nil, scope: scope)
      {:ok, child} = Tags.create_tag("partner-dance", "Partner dance", nil, scope: scope)
      {:ok, other_parent} = Tags.create_tag("social", "Social", nil, scope: scope)

      assert {:ok, _edge} = Tags.link_tags(root.id, child.id, scope: scope)
      assert {:ok, _edge} = Tags.link_tags(other_parent.id, child.id, scope: scope)

      assert {:ok, [edge_a, _edge_b]} =
               TagEdge
               |> Ash.read(authorize?: false, domain: Wik.Tags, scope: scope)
               |> then(fn {:ok, edges} -> {:ok, Enum.sort_by(edges, & &1.parent_tag_id)} end)

      assert {:ok, _edge} =
               Tags.unlink_tags(edge_a.parent_tag_id, edge_a.child_tag_id, scope: scope)

      assert {:ok, tags_after_unlink} =
               Ash.read(Tag, authorize?: false, domain: Wik.Tags, scope: scope)

      assert Enum.map(tags_after_unlink, & &1.id) |> Enum.sort() ==
               Enum.sort([root.id, child.id, other_parent.id])

      assert {:ok, _tag} = Tags.destroy_tag(child.id, scope: scope)

      assert {:ok, []} = Ash.read(TagEdge, authorize?: false, domain: Wik.Tags, scope: scope)
    end
  end

  defp owner_fixture do
    owner = generate(user())
    group = generate(group(author: owner))
    add_membership(group, owner, :owner)
    %{group: group, owner: owner}
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
