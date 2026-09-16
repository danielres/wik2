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

      matching_grant =
        create_grant(email_rule, generate(user()), "ada@example.com", "google-matching")

      unrelated_grant =
        create_grant(email_rule, generate(user()), "grace@example.com", "google-unrelated")

      assert {:ok, _email_rule} = Access.google_revoke_email_rule(email_rule.id, owner)

      assert {:error, :google_email_rule_not_found} =
               Access.google_apply_email_access(identity.user)

      assert_grant_status(grant, :inactive)
      assert_grant_status(matching_grant, :inactive)
      assert_grant_status(unrelated_grant, :active)
    end

    test "revoking email access without grants succeeds" do
      owner = generate(user())
      space = generate(space(author: owner))
      create_membership(space, owner, :owner)

      {:ok, email_rule} =
        Access.google_upsert_email_rule(
          space,
          %{"email" => "ada@example.com", "membership_type" => "member"},
          owner
        )

      assert {:ok, revoked_email_rule} =
               Access.google_revoke_email_rule(email_rule.id, owner)

      assert revoked_email_rule.revoked_at
    end
  end

  defp assert_grant_status(grant, status) do
    assert {:ok, grant} = Ash.get(Grant, grant.id, authorize?: false, domain: Access)
    assert grant.status == status
  end

  defp create_grant(email_rule, user, email, provider_user_id) do
    {:ok, identity} =
      Access.create_external_identity(
        %{
          email: email,
          provider: :google,
          provider_user_id: provider_user_id,
          user_id: user.id
        },
        authorize?: false
      )

    {:ok, grant} =
      Access.create_grant(
        %{
          external_identity_id: identity.id,
          granted_by_user_id: email_rule.granted_by_user_id,
          last_verified_at: DateTime.utc_now(),
          source_id: email_rule.source_id,
          status: :active,
          user_id: user.id
        },
        authorize?: false
      )

    grant
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
