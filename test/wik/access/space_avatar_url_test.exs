defmodule Wik.Access.SpaceAvatarUrlTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Access
  alias Wik.Access.ExternalIdentity
  alias Wik.Access.Grant
  alias Wik.Access.Source

  test "returns the first non-nil avatar url for a user's grants in a space" do
    user = generate(user())
    space = generate(space())

    source_without_avatar =
      create_source(space, user, "source-without-avatar")

    identity_without_avatar =
      create_identity(user,
        provider_user_id: "telegram-user-without-avatar",
        avatar_url: nil
      )

    older = DateTime.utc_now() |> DateTime.add(-60, :second)
    newer = DateTime.utc_now()

    create_grant(source_without_avatar, identity_without_avatar, user, newer)

    source_with_avatar =
      create_source(space, user, "source-with-avatar")

    identity_with_avatar =
      create_identity(user,
        provider_user_id: "telegram-user-with-avatar",
        avatar_url: "https://telegram.example/avatar.png"
      )

    create_grant(source_with_avatar, identity_with_avatar, user, older)

    assert {:ok, "https://telegram.example/avatar.png"} =
             Access.get_user_space_avatar_url(user, space)
  end

  test "lists avatar urls keyed by user for the first usable space grant" do
    space = generate(space())
    user_with_avatar = generate(user())
    user_without_avatar = generate(user())

    source_with_avatar =
      create_source(space, user_with_avatar, "source-with-avatar-map")

    source_without_avatar =
      create_source(space, user_without_avatar, "source-without-avatar-map")

    create_grant(
      source_without_avatar,
      create_identity(user_without_avatar,
        provider_user_id: "telegram-user-without-avatar-map",
        avatar_url: nil
      ),
      user_without_avatar,
      DateTime.utc_now()
    )

    create_grant(
      source_with_avatar,
      create_identity(user_with_avatar,
        provider_user_id: "telegram-user-with-avatar-map",
        avatar_url: "https://telegram.example/avatar-map.png"
      ),
      user_with_avatar,
      DateTime.utc_now()
    )

    assert {:ok, avatar_urls} =
             Access.list_space_avatar_urls(space.id, [user_with_avatar.id, user_without_avatar.id])

    assert avatar_urls == %{user_with_avatar.id => "https://telegram.example/avatar-map.png"}
  end

  defp create_source(space, user, provider_source_id) do
    Ash.create!(
      Source,
      %{
        claimed_at: DateTime.utc_now(),
        claimed_by_user_id: user.id,
        space_id: space.id,
        provider: :telegram,
        provider_source_id: provider_source_id,
        status: :active,
        title: "Telegram Space"
      },
      authorize?: false,
      domain: Wik.Access
    )
  end

  defp create_identity(user, opts) do
    Ash.create!(
      ExternalIdentity,
      %{
        avatar_url: Keyword.fetch!(opts, :avatar_url),
        display_name: "Telegram User",
        provider: :telegram,
        provider_user_id: Keyword.fetch!(opts, :provider_user_id),
        user_id: user.id
      },
      authorize?: false,
      domain: Wik.Access
    )
  end

  defp create_grant(source, identity, user, last_verified_at) do
    Ash.create!(
      Grant,
      %{
        external_identity_id: identity.id,
        last_verified_at: last_verified_at,
        source_id: source.id,
        status: :active,
        user_id: user.id
      },
      authorize?: false,
      domain: Wik.Access
    )
  end
end
