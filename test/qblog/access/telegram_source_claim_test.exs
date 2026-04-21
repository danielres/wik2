defmodule Qblog.Access.TelegramSourceClaimTest do
  use Qblog.DataCase, async: true

  alias Qblog.Access
  alias Qblog.Access.Source
  alias Qblog.Accounts.GroupUserRelation

  require Ash.Query

  defmodule CreatorTelegramProvider do
    def get_chat_member("-1001", "42"), do: {:ok, %{"status" => "creator"}}
    def get_chat_member(_chat_id, "42"), do: {:ok, %{"status" => "member"}}
  end

  defmodule MemberTelegramProvider do
    def get_chat_member(_chat_id, "42"), do: {:ok, %{"status" => "member"}}
  end

  describe "list_claimable_telegram_sources/2" do
    test "returns pending sources where the Telegram identity is the chat creator" do
      user = create_telegram_user()
      source = create_pending_source("-1001", "Wiktest Local Group 1")
      create_pending_source("-1002", "Wiktest Local Group 2")

      assert [claimable_source] =
               Access.list_claimable_telegram_sources(user, CreatorTelegramProvider)

      assert claimable_source.id == source.id
    end
  end

  describe "claim_telegram_source_with_new_group/3" do
    test "creates a group and activates the source for Telegram chat creators" do
      user = create_telegram_user()
      source = create_pending_source("-1001", "Wiktest Local Group 1")

      assert {:ok, {group, source}} =
               Access.claim_telegram_source_with_new_group(
                 source.id,
                 user,
                 CreatorTelegramProvider
               )

      assert group.name == "wiktest-local-group-1"
      assert source.status == :active
      assert source.group_id == group.id
      assert source.claimed_by_user_id == user.id
      assert source.claimed_at != nil

      assert {:ok, membership} =
               GroupUserRelation
               |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id)
               |> Ash.read_one(authorize?: false)

      assert membership.type == :owner
    end

    test "rejects non-creator Telegram members" do
      user = create_telegram_user()
      source = create_pending_source("-1001", "Wiktest Local Group 1")

      assert {:error, :telegram_source_claim_requires_creator} =
               Access.claim_telegram_source_with_new_group(
                 source.id,
                 user,
                 MemberTelegramProvider
               )

      assert {:ok, source} = Ash.get(Source, source.id, authorize?: false)
      assert source.status == :pending
      assert source.group_id == nil
    end
  end

  defp create_telegram_user do
    {:ok, identity} =
      Access.find_or_create_identity_from_telegram(%{
        "family_name" => "Lovelace",
        "given_name" => "Ada",
        "preferred_username" => "ada",
        "sub" => 42
      })

    identity.user
  end

  defp create_pending_source(provider_source_id, title) do
    {:ok, source} =
      Access.upsert_pending_telegram_source(%{
        metadata: %{
          "chat" => %{
            "id" => provider_source_id,
            "title" => title,
            "type" => "group"
          },
          "kind" => "telegram_chat"
        },
        provider_source_id: provider_source_id,
        title: title
      })

    source
  end
end
