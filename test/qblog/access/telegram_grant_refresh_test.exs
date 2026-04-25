defmodule Qblog.Access.TelegramGrantRefreshTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Access
  alias Qblog.Access.ExternalIdentity
  alias Qblog.Access.Grant
  alias Qblog.Access.Source
  alias Qblog.Access.Telegram
  alias Qblog.Accounts
  alias Qblog.Accounts.GroupUserRelation
  alias Qblog.Scope

  require Ash.Query

  defmodule MemberTelegramProvider do
    def get_chat_member("-1001", "42"), do: {:ok, %{"status" => "member"}}
  end

  defmodule LeftTelegramProvider do
    def get_chat_member("-1001", "42"), do: {:ok, %{"status" => "left"}}
  end

  describe "refresh_grants/2" do
    test "activates grants and creates plain member relations for Telegram members" do
      user = create_telegram_user()
      group = generate(group())
      source = create_active_source(group, "-1001")

      assert {:ok, [grant]} = Telegram.refresh_grants(user, MemberTelegramProvider)

      assert grant.status == :active
      assert grant.source_id == source.id
      assert grant.user_id == user.id

      assert {:ok, membership} =
               GroupUserRelation
               |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id)
               |> Ash.read_one(authorize?: false, domain: Qblog.Accounts)

      assert membership.type == :member
    end

    test "deactivates grants when Telegram no longer reports membership" do
      user = create_telegram_user()
      group = generate(group())
      source = create_active_source(group, "-1001")
      create_active_grant(source, user)

      assert {:ok, [grant]} = Telegram.refresh_grants(user, LeftTelegramProvider)

      assert grant.status == :inactive

      assert {:ok, nil} =
               GroupUserRelation
               |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id)
               |> Ash.read_one(authorize?: false, domain: Qblog.Accounts)
    end

    test "keeps existing local app roles unchanged" do
      user = create_telegram_user()
      group = generate(group())
      create_active_source(group, "-1001")
      create_membership(group, user, :admin)

      assert {:ok, [_grant]} = Telegram.refresh_grants(user, MemberTelegramProvider)

      assert {:ok, membership} =
               GroupUserRelation
               |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id)
               |> Ash.read_one(authorize?: false, domain: Qblog.Accounts)

      assert membership.type == :admin
    end

    test "active Telegram grants make the group visible" do
      user = create_telegram_user()
      group = generate(group())
      create_active_source(group, "-1001")

      assert {:ok, [_grant]} = Telegram.refresh_grants(user, MemberTelegramProvider)

      assert Ash.can?({group, :read}, scope(user, group))
      assert {:ok, groups} = Accounts.list_groups(scope: scope(user, group))
      assert Enum.any?(groups, &(&1.id == group.id))
    end

    test "inactive Telegram grants hide the group but keep the local role row" do
      user = create_telegram_user()
      group = generate(group())
      source = create_active_source(group, "-1001")
      create_membership(group, user, :admin)
      create_active_grant(source, user)

      assert {:ok, [grant]} = Telegram.refresh_grants(user, LeftTelegramProvider)

      assert grant.status == :inactive
      refute Ash.can?({group, :read}, scope(user, group))
      refute Ash.can?({group, :update}, scope(user, group))

      assert {:ok, groups} = Accounts.list_groups(scope: scope(user, group))
      refute Enum.any?(groups, &(&1.id == group.id))

      assert {:ok, membership} =
               GroupUserRelation
               |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id)
               |> Ash.read_one(authorize?: false, domain: Qblog.Accounts)

      assert membership.type == :admin
    end

    test "inactive Telegram grants do not affect owner access" do
      user = create_telegram_user()
      group = generate(group(author: user))
      source = create_active_source(group, "-1001")
      create_membership(group, user, :owner)
      create_active_grant(source, user)

      assert {:ok, [grant]} = Telegram.refresh_grants(user, LeftTelegramProvider)

      assert grant.status == :inactive
      assert Ash.can?({group, :read}, scope(user, group))
      assert Ash.can?({group, :update}, scope(user, group))

      assert {:ok, groups} = Accounts.list_groups(scope: scope(user, group))
      assert Enum.any?(groups, &(&1.id == group.id))
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

  defp create_active_source(group, provider_source_id) do
    {:ok, source} =
      Ash.create(
        Source,
        %{
          group_id: group.id,
          metadata: %{"kind" => "telegram_chat"},
          provider: :telegram,
          provider_source_id: provider_source_id,
          status: :active,
          title: "Telegram Group"
        },
        authorize?: false
      )

    source
  end

  defp create_active_grant(source, user) do
    {:ok, identity} =
      ExternalIdentity
      |> Ash.Query.filter(provider == :telegram and user_id == ^user.id)
      |> Ash.read_one(authorize?: false, domain: Access)

    {:ok, grant} =
      Ash.create(
        Grant,
        %{
          external_identity_id: identity.id,
          last_verified_at: DateTime.utc_now(),
          source_id: source.id,
          status: :active,
          user_id: user.id
        },
        authorize?: false
      )

    grant
  end

  defp create_membership(group, user, type) do
    Ash.create!(
      GroupUserRelation,
      %{group_id: group.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Qblog.Accounts
    )
  end

  defp scope(actor, tenant) do
    %Scope{actor: actor, tenant: tenant}
  end
end
