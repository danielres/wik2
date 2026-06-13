defmodule Wik.Access.Telegram.GrantRefreshTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Access
  alias Wik.Access.ExternalIdentity
  alias Wik.Access.Grant
  alias Wik.Access.Source
  alias Wik.Access.Telegram.Workflow, as: Telegram
  alias Wik.Accounts
  alias Wik.Accounts.Membership
  alias Wik.Scope

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
      space = generate(space())
      source = create_active_source(space, "-1001")

      assert {:ok, [grant]} = Telegram.refresh_grants(user, MemberTelegramProvider)

      assert grant.status == :active
      assert grant.source_id == source.id
      assert grant.user_id == user.id

      assert {:ok, membership} =
               Membership
               |> Ash.Query.filter(space_id == ^space.id and user_id == ^user.id)
               |> Ash.read_one(authorize?: false, domain: Wik.Accounts)

      assert membership.type == :member
    end

    test "deactivates grants when Telegram no longer reports membership" do
      user = create_telegram_user()
      space = generate(space())
      source = create_active_source(space, "-1001")
      create_active_grant(source, user)

      assert {:ok, [grant]} = Telegram.refresh_grants(user, LeftTelegramProvider)

      assert grant.status == :inactive

      assert {:ok, nil} =
               Membership
               |> Ash.Query.filter(space_id == ^space.id and user_id == ^user.id)
               |> Ash.read_one(authorize?: false, domain: Wik.Accounts)
    end

    test "does not create inactive grants when Telegram never reported membership" do
      user = create_telegram_user()
      space = generate(space())
      source = create_active_source(space, "-1001")

      assert {:ok, []} = Telegram.refresh_grants(user, LeftTelegramProvider)

      assert {:ok, nil} =
               Grant
               |> Ash.Query.filter(source_id == ^source.id and user_id == ^user.id)
               |> Ash.read_one(authorize?: false, domain: Wik.Access)
    end

    test "keeps existing local app roles unchanged" do
      user = create_telegram_user()
      space = generate(space())
      create_active_source(space, "-1001")
      create_membership(space, user, :admin)

      assert {:ok, [_grant]} = Telegram.refresh_grants(user, MemberTelegramProvider)

      assert {:ok, membership} =
               Membership
               |> Ash.Query.filter(space_id == ^space.id and user_id == ^user.id)
               |> Ash.read_one(authorize?: false, domain: Wik.Accounts)

      assert membership.type == :admin
    end

    test "active Telegram grants make the space visible" do
      user = create_telegram_user()
      space = generate(space())
      create_active_source(space, "-1001")

      assert {:ok, [_grant]} = Telegram.refresh_grants(user, MemberTelegramProvider)

      assert Ash.can?({space, :read}, scope(user, space))
      assert {:ok, spaces} = Accounts.list_spaces(scope: scope(user, space))
      assert Enum.any?(spaces, &(&1.id == space.id))
    end

    test "inactive Telegram grants hide the space but keep the local role row" do
      user = create_telegram_user()
      space = generate(space())
      source = create_active_source(space, "-1001")
      create_membership(space, user, :admin)
      create_active_grant(source, user)

      assert {:ok, [grant]} = Telegram.refresh_grants(user, LeftTelegramProvider)

      assert grant.status == :inactive
      refute Ash.can?({space, :read}, scope(user, space))
      refute Ash.can?({space, :update}, scope(user, space))

      assert {:ok, spaces} = Accounts.list_spaces(scope: scope(user, space))
      refute Enum.any?(spaces, &(&1.id == space.id))

      assert {:ok, membership} =
               Membership
               |> Ash.Query.filter(space_id == ^space.id and user_id == ^user.id)
               |> Ash.read_one(authorize?: false, domain: Wik.Accounts)

      assert membership.type == :admin
    end

    test "inactive Telegram grants do not affect owner access" do
      user = create_telegram_user()
      space = generate(space(author: user))
      source = create_active_source(space, "-1001")
      create_membership(space, user, :owner)
      create_active_grant(source, user)

      assert {:ok, [grant]} = Telegram.refresh_grants(user, LeftTelegramProvider)

      assert grant.status == :inactive
      assert Ash.can?({space, :read}, scope(user, space))
      assert Ash.can?({space, :update}, scope(user, space))

      assert {:ok, spaces} = Accounts.list_spaces(scope: scope(user, space))
      assert Enum.any?(spaces, &(&1.id == space.id))
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

  defp create_active_source(space, provider_source_id) do
    {:ok, source} =
      Ash.create(
        Source,
        %{
          space_id: space.id,
          metadata: %{"kind" => "telegram_chat"},
          provider: :telegram,
          provider_source_id: provider_source_id,
          status: :active,
          title: "Telegram Space"
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

  defp create_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
  end

  defp scope(actor, tenant) do
    %Scope{actor: actor, tenant: tenant}
  end
end
