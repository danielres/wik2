defmodule Wik.Access.Telegram.SourceClaimTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Access
  alias Wik.Access.Grant
  alias Wik.Access.Source
  alias Wik.Access.Telegram.Workflow, as: Telegram
  alias Wik.Accounts.Membership

  require Ash.Query

  defmodule CreatorTelegramProvider do
    def get_chat_member("-1001", "42"), do: {:ok, %{"status" => "creator"}}
    def get_chat_member(_chat_id, "42"), do: {:ok, %{"status" => "member"}}
  end

  defmodule MemberTelegramProvider do
    def get_chat_member(_chat_id, "42"), do: {:ok, %{"status" => "member"}}
  end

  describe "list_claimable_sources/2" do
    test "returns pending sources where the Telegram identity is the chat creator" do
      user = create_telegram_user()
      source = create_pending_source("-1001", "Wiktest Local Space 1")
      create_pending_source("-1002", "Wiktest Local Space 2")

      assert [claimable_source] =
               Telegram.list_claimable_sources(user, CreatorTelegramProvider)

      assert claimable_source.id == source.id
    end
  end

  describe "claim_source_with_new_space/3" do
    test "creates a space and activates the source for Telegram chat creators" do
      user = create_telegram_user()
      source = create_pending_source("-1001", "Wiktest Local Space 1")

      assert {:ok, {space, source}} =
               Telegram.claim_source_with_new_space(
                 source.id,
                 %{
                   "description" => "Created from Telegram group #{source.title}",
                   "name" => source.title,
                   "slug" => "wiktest-local-space-1"
                 },
                 user,
                 CreatorTelegramProvider
               )

      assert space.name == "Wiktest Local Space 1"
      assert space.slug == "wiktest-local-space-1"
      assert source.status == :active
      assert source.space_id == space.id
      assert source.claimed_by_user_id == user.id
      assert source.claimed_at != nil

      assert {:ok, membership} =
               Membership
               |> Ash.Query.filter(space_id == ^space.id and user_id == ^user.id)
               |> Ash.read_one(authorize?: false)

      assert membership.type == :owner

      assert_owner_grant(source, user)
    end

    test "rejects non-creator Telegram members" do
      user = create_telegram_user()
      source = create_pending_source("-1001", "Wiktest Local Space 1")

      assert {:error, :telegram_source_claim_requires_creator} =
               Telegram.claim_source_with_new_space(
                 source.id,
                 %{
                   "description" => "Created from Telegram group #{source.title}",
                   "name" => source.title,
                   "slug" => "wiktest-local-space-1"
                 },
                 user,
                 MemberTelegramProvider
               )

      assert {:ok, source} = Ash.get(Source, source.id, authorize?: false)
      assert source.status == :pending
      assert source.space_id == nil
    end

    test "rejects already claimed sources" do
      user = create_telegram_user()
      space = generate(space(author: user))
      source = create_pending_source("-1001", "Wiktest Local Space 1")
      create_membership(space, user, :owner)

      assert {:ok, {_space, _source}} =
               Telegram.claim_source_with_existing_space(
                 source.id,
                 space.id,
                 user,
                 CreatorTelegramProvider
               )

      assert {:error, :pending_source_required} =
               Telegram.claim_source_with_new_space(
                 source.id,
                 %{
                   "description" => "Created from Telegram group #{source.title}",
                   "name" => source.title,
                   "slug" => "wiktest-local-space-1"
                 },
                 user,
                 CreatorTelegramProvider
               )
    end
  end

  describe "claim_source_with_existing_space/4" do
    test "activates the source for an existing space owned by the Telegram creator" do
      user = create_telegram_user()
      space = generate(space(author: user))
      source = create_pending_source("-1001", "Wiktest Local Space 1")
      create_membership(space, user, :owner)

      assert {:ok, {claimed_space, source}} =
               Telegram.claim_source_with_existing_space(
                 source.id,
                 space.id,
                 user,
                 CreatorTelegramProvider
               )

      assert claimed_space.id == space.id
      assert source.status == :active
      assert source.space_id == space.id
      assert source.claimed_by_user_id == user.id
      assert source.claimed_at != nil

      assert_owner_grant(source, user)
    end

    test "rejects spaces not owned by the Telegram creator" do
      user = create_telegram_user()
      space = generate(space())
      source = create_pending_source("-1001", "Wiktest Local Space 1")
      create_membership(space, user, :admin)

      assert {:error, :space_owner_required} =
               Telegram.claim_source_with_existing_space(
                 source.id,
                 space.id,
                 user,
                 CreatorTelegramProvider
               )

      assert {:ok, source} = Ash.get(Source, source.id, authorize?: false)
      assert source.status == :pending
      assert source.space_id == nil
    end
  end

  defp create_telegram_user do
    generate(user())

    {:ok, identity} =
      Access.telegram_find_or_create_identity(%{
        "family_name" => "Lovelace",
        "given_name" => "Ada",
        "preferred_username" => "ada",
        "sub" => 42
      })

    identity.user
  end

  defp create_pending_source(provider_source_id, title) do
    {:ok, source} =
      Access.telegram_upsert_pending_source(%{
        metadata: %{
          "chat" => %{
            "id" => provider_source_id,
            "title" => title,
            "type" => "space"
          },
          "kind" => "telegram_chat"
        },
        provider_source_id: provider_source_id,
        title: title
      })

    source
  end

  defp create_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
  end

  defp assert_owner_grant(source, user) do
    assert {:ok, grant} =
             Grant
             |> Ash.Query.filter(source_id == ^source.id and user_id == ^user.id)
             |> Ash.read_one(authorize?: false, domain: Wik.Access)

    assert grant.status == :active
  end
end
