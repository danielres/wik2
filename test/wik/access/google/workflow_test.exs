defmodule Wik.Access.Google.WorkflowTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Access
  alias Wik.Access.Grant
  alias Wik.Accounts
  alias Wik.Accounts.Membership

  describe "google_apply_email_access/1" do
    test "rejects users without matching active email access" do
      {:ok, identity} =
        Access.google_find_or_create_identity(%{
          "email" => "ada@example.com",
          "email_verified" => true,
          "name" => "Ada",
          "sub" => "google-42"
        })

      assert {:error, :google_email_rule_not_found} =
               Access.google_apply_email_access(identity.user)
    end

    test "creates memberships and active grants from matching email rules" do
      owner = generate(user())
      space = generate(space(author: owner))
      create_membership(space, owner, :owner)

      {:ok, _email_rule} =
        Access.google_upsert_email_rule(
          space,
          %{"email" => "ada@example.com", "membership_type" => "admin"},
          owner
        )

      {:ok, identity} =
        Access.google_find_or_create_identity(%{
          "email" => "ADA@example.com",
          "email_verified" => true,
          "name" => "Ada",
          "sub" => "google-42"
        })

      assert {:ok, [grant]} = Access.google_apply_email_access(identity.user)
      assert grant.status == :active
      assert grant.granted_by_user_id == owner.id

      assert {:ok, membership} = Accounts.get_membership(space, identity.user)
      assert membership.type == :admin
    end

    test "does not downgrade an existing owner membership" do
      owner = generate(user())
      user = generate(user(email: "ada@example.com"))
      space = generate(space(author: owner))
      create_membership(space, owner, :owner)

      create_membership(space, user, :owner)

      {:ok, _email_rule} =
        Access.google_upsert_email_rule(
          space,
          %{"email" => "ada@example.com", "membership_type" => "member"},
          owner
        )

      {:ok, identity} =
        Access.google_find_or_create_identity(%{
          "email" => "ada@example.com",
          "email_verified" => true,
          "name" => "Ada",
          "sub" => "google-42"
        })

      assert {:ok, [_grant]} = Access.google_apply_email_access(identity.user)

      assert {:ok, membership} = Accounts.get_membership(space, user)
      assert membership.type == :owner
    end

    test "does not downgrade an existing admin membership" do
      owner = generate(user())
      user = generate(user(email: "ada@example.com"))
      space = generate(space(author: owner))
      create_membership(space, owner, :owner)

      create_membership(space, user, :admin)

      {:ok, _email_rule} =
        Access.google_upsert_email_rule(
          space,
          %{"email" => "ada@example.com", "membership_type" => "member"},
          owner
        )

      {:ok, identity} =
        Access.google_find_or_create_identity(%{
          "email" => "ada@example.com",
          "email_verified" => true,
          "name" => "Ada",
          "sub" => "google-42"
        })

      assert {:ok, [_grant]} = Access.google_apply_email_access(identity.user)

      assert {:ok, membership} = Accounts.get_membership(space, user)
      assert membership.type == :admin
    end

    test "does not promote an existing member membership" do
      owner = generate(user())
      user = generate(user(email: "ada@example.com"))
      space = generate(space(author: owner))
      create_membership(space, owner, :owner)

      create_membership(space, user, :member)

      {:ok, _email_rule} =
        Access.google_upsert_email_rule(
          space,
          %{"email" => "ada@example.com", "membership_type" => "admin"},
          owner
        )

      {:ok, identity} =
        Access.google_find_or_create_identity(%{
          "email" => "ada@example.com",
          "email_verified" => true,
          "name" => "Ada",
          "sub" => "google-42"
        })

      assert {:ok, [_grant]} = Access.google_apply_email_access(identity.user)

      assert {:ok, membership} = Accounts.get_membership(space, user)
      assert membership.type == :member
    end

    test "revoking email access prevents future access application and inactivates grants" do
      owner = generate(user())
      space = generate(space(author: owner))
      create_membership(space, owner, :owner)

      {:ok, email_rule} =
        Access.google_upsert_email_rule(
          space,
          %{"email" => "ada@example.com", "membership_type" => "member"},
          owner
        )

      {:ok, identity} =
        Access.google_find_or_create_identity(%{
          "email" => "ada@example.com",
          "email_verified" => true,
          "name" => "Ada",
          "sub" => "google-42"
        })

      assert {:ok, [grant]} = Access.google_apply_email_access(identity.user)

      assert {:ok, _email_rule} = Access.google_revoke_email_rule(email_rule.id, owner)

      assert {:error, :google_email_rule_not_found} =
               Access.google_apply_email_access(identity.user)

      assert {:ok, grant} = Ash.get(Grant, grant.id, authorize?: false, domain: Access)
      assert grant.status == :inactive
    end
  end

  defp create_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Accounts
    )
  end
end
