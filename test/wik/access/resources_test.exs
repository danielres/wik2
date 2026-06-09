defmodule Wik.Access.ResourcesTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Access
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

    test "can be loaded from a user" do
      user = generate(user())
      identity = create_external_identity(user)

      assert {:ok, user} = Ash.load(user, [:external_identities], authorize?: false)

      assert Enum.map(user.external_identities, & &1.id) == [identity.id]
    end
  end

  describe "sources" do
    test "are unique per provider source" do
      assert {:ok, _source} = Ash.create(Source, telegram_source_attrs(), authorize?: false)

      assert {:error, _error} = Ash.create(Source, telegram_source_attrs(), authorize?: false)
    end

    test "can belong to a space and a claiming user" do
      space = generate(space())
      user = generate(user())
      source = create_source(space, user)

      assert {:ok, source} = Ash.load(source, [:claimed_by_user, :space], authorize?: false)

      assert source.claimed_by_user.id == user.id
      assert source.space.id == space.id
    end

    test "list_space_access_sources/1 returns claimed sources for the selected space with grants loaded" do
      user = generate(user())
      space = generate(space())
      other_space = generate(space())
      source = create_source(space, user)
      other_source = create_source(other_space, user)
      pending_source = create_source(space, user, claimed_at: nil, status: :pending)
      identity = create_external_identity(user)

      {:ok, grant} =
        Ash.create(Grant, telegram_grant_attrs(source, identity, user), authorize?: false)

      {:ok, _other_grant} =
        Ash.create(Grant, telegram_grant_attrs(other_source, identity, user), authorize?: false)

      {:ok, _pending_grant} =
        Ash.create(Grant, telegram_grant_attrs(pending_source, identity, user), authorize?: false)

      assert {:ok, [listed_source]} = Access.list_space_access_sources(space)

      assert listed_source.id == source.id

      assert [%{id: grant_id, external_identity: loaded_identity, user: loaded_user}] =
               listed_source.grants

      assert grant_id == grant.id
      assert loaded_identity.id == identity.id
      assert loaded_user.id == user.id
    end

    test "list_space_access_sources/1 keeps grants scoped to each source" do
      first_user = generate(user())
      second_user = generate(user())
      space = generate(space())
      first_source = create_source(space, first_user, title: "First Telegram Group")
      second_source = create_source(space, second_user, title: "Second Telegram Group")
      first_identity = create_external_identity(first_user, provider_user_id: "telegram-user-1")
      second_identity = create_external_identity(second_user, provider_user_id: "telegram-user-2")

      {:ok, first_grant} =
        Ash.create(Grant, telegram_grant_attrs(first_source, first_identity, first_user),
          authorize?: false
        )

      {:ok, second_grant} =
        Ash.create(Grant, telegram_grant_attrs(second_source, second_identity, second_user),
          authorize?: false
        )

      assert {:ok, sources} = Access.list_space_access_sources(space)

      assert [
               %{id: first_source_id, grants: [%{id: first_grant_id}]},
               %{id: second_source_id, grants: [%{id: second_grant_id}]}
             ] = sources

      assert first_source_id == first_source.id
      assert first_grant_id == first_grant.id
      assert second_source_id == second_source.id
      assert second_grant_id == second_grant.id
    end
  end

  describe "grants" do
    test "are unique per source and user" do
      user = generate(user())
      source = create_source(generate(space()), user)
      identity = create_external_identity(user)
      attrs = telegram_grant_attrs(source, identity, user)

      assert {:ok, _grant} = Ash.create(Grant, attrs, authorize?: false)
      assert {:error, _error} = Ash.create(Grant, attrs, authorize?: false)
    end

    test "belong to source, external identity, and user" do
      user = generate(user())
      source = create_source(generate(space()), user)
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

  defp create_external_identity(user, overrides \\ []) do
    {:ok, identity} =
      Ash.create(
        ExternalIdentity,
        Map.merge(telegram_identity_attrs(user), Enum.into(overrides, %{})),
        authorize?: false
      )

    identity
  end

  defp create_source(space, user, overrides \\ []) do
    {:ok, source} =
      Ash.create(
        Source,
        telegram_source_attrs(
          Keyword.merge(
            [
              claimed_at: DateTime.utc_now(),
              space_id: space.id,
              claimed_by_user_id: user.id,
              status: :active,
              provider_source_id: "telegram-chat-#{System.unique_integer([:positive])}"
            ],
            overrides
          )
        ),
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
      space_id: Keyword.get(overrides, :space_id),
      metadata: %{"kind" => "space"},
      provider: :telegram,
      provider_source_id: Keyword.get(overrides, :provider_source_id, "telegram-chat-1"),
      status: Keyword.get(overrides, :status, :pending),
      title: "Telegram Space"
    }
  end
end
