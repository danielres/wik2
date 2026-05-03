defmodule Wik.Access.ResourcesTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Access.ExternalIdentity
  alias Wik.Access.Grant
  alias Wik.Access.Source

  describe "external identities" do
    test "are unique per provider user" do
      user = generate(user())

      assert {:ok, _identity} =
               Ash.create(ExternalIdentity, telegram_identity_attrs(user), authorize?: false)

      assert {:error, _error} =
               Ash.create(ExternalIdentity, telegram_identity_attrs(user), authorize?: false)
    end

    test "belong to a user" do
      user = generate(user())
      identity = create_external_identity(user)

      assert {:ok, identity} = Ash.load(identity, [:user], authorize?: false)

      assert identity.user.id == user.id
    end
  end

  describe "sources" do
    test "are unique per provider source" do
      assert {:ok, _source} = Ash.create(Source, telegram_source_attrs(), authorize?: false)

      assert {:error, _error} = Ash.create(Source, telegram_source_attrs(), authorize?: false)
    end

    test "can belong to a group and a claiming user" do
      group = generate(group())
      user = generate(user())
      source = create_source(group, user)

      assert {:ok, source} = Ash.load(source, [:claimed_by_user, :group], authorize?: false)

      assert source.claimed_by_user.id == user.id
      assert source.group.id == group.id
    end
  end

  describe "grants" do
    test "are unique per source and user" do
      user = generate(user())
      source = create_source(generate(group()), user)
      identity = create_external_identity(user)
      attrs = telegram_grant_attrs(source, identity, user)

      assert {:ok, _grant} = Ash.create(Grant, attrs, authorize?: false)
      assert {:error, _error} = Ash.create(Grant, attrs, authorize?: false)
    end

    test "belong to source, external identity, and user" do
      user = generate(user())
      source = create_source(generate(group()), user)
      identity = create_external_identity(user)

      assert {:ok, grant} =
               Ash.create(Grant, telegram_grant_attrs(source, identity, user), authorize?: false)

      assert {:ok, grant} =
               Ash.load(grant, [:external_identity, :source, :user], authorize?: false)

      assert grant.external_identity.id == identity.id
      assert grant.source.id == source.id
      assert grant.user.id == user.id
    end
  end

  defp create_external_identity(user) do
    {:ok, identity} =
      Ash.create(ExternalIdentity, telegram_identity_attrs(user), authorize?: false)

    identity
  end

  defp create_source(group, user) do
    {:ok, source} =
      Ash.create(
        Source,
        telegram_source_attrs(group_id: group.id, claimed_by_user_id: user.id, status: :active),
        authorize?: false
      )

    source
  end

  defp telegram_grant_attrs(source, identity, user) do
    %{
      external_identity_id: identity.id,
      last_verified_at: DateTime.utc_now(),
      source_id: source.id,
      status: :active,
      user_id: user.id
    }
  end

  defp telegram_identity_attrs(user) do
    %{
      avatar_url: "https://telegram.example/avatar.png",
      display_name: "Telegram User",
      metadata: %{"first_name" => "Telegram"},
      provider: :telegram,
      provider_user_id: "telegram-user-1",
      user_id: user.id,
      username: "telegram_user"
    }
  end

  defp telegram_source_attrs(overrides \\ []) do
    %{
      claimed_at: Keyword.get(overrides, :claimed_at),
      claimed_by_user_id: Keyword.get(overrides, :claimed_by_user_id),
      group_id: Keyword.get(overrides, :group_id),
      metadata: %{"kind" => "group"},
      provider: :telegram,
      provider_source_id: "telegram-chat-1",
      status: Keyword.get(overrides, :status, :pending),
      title: "Telegram Group"
    }
  end
end
