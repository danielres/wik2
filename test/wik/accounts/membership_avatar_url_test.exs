defmodule Wik.Accounts.MembershipAvatarUrlTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Access.ExternalIdentity
  alias Wik.Access.Grant
  alias Wik.Access.Source
  alias Wik.Accounts.Membership

  require Ash.Query

  test "loads avatar_url from the first usable grant in the membership space" do
    user = generate(user())
    space = generate(space())
    membership = create_membership(space, user)

    create_grant(
      space,
      user,
      provider_source_id: "source-without-avatar",
      provider_user_id: "telegram-user-without-avatar",
      avatar_url: nil,
      last_verified_at: DateTime.utc_now()
    )

    create_grant(
      space,
      user,
      provider_source_id: "source-with-avatar",
      provider_user_id: "telegram-user-with-avatar",
      avatar_url: "https://telegram.example/avatar.png",
      last_verified_at: DateTime.utc_now() |> DateTime.add(-60, :second)
    )

    assert {:ok, membership} = Ash.load(membership, [:avatar_url], authorize?: false)

    assert membership.avatar_url == "https://telegram.example/avatar.png"
  end

  test "prefers the most recently verified grant when multiple avatars are available" do
    user = generate(user())
    space = generate(space())
    membership = create_membership(space, user)

    older = DateTime.utc_now() |> DateTime.add(-60, :second)
    newer = DateTime.utc_now()

    create_grant(
      space,
      user,
      provider_source_id: "source-older-avatar",
      provider_user_id: "telegram-user-older-avatar",
      avatar_url: "https://telegram.example/older.png",
      last_verified_at: older
    )

    create_grant(
      space,
      user,
      provider_source_id: "source-newer-avatar",
      provider_user_id: "telegram-user-newer-avatar",
      avatar_url: "https://telegram.example/newer.png",
      last_verified_at: newer
    )

    assert {:ok, membership} = Ash.load(membership, [:avatar_url], authorize?: false)

    assert membership.avatar_url == "https://telegram.example/newer.png"
  end

  defp create_membership(space, user) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: :member, user_id: user.id},
      authorize?: false
    )
  end

  defp create_grant(space, user, opts) do
    source =
      Ash.create!(
        Source,
        %{
          claimed_at: DateTime.utc_now(),
          claimed_by_user_id: user.id,
          space_id: space.id,
          provider: :telegram,
          provider_source_id: Keyword.fetch!(opts, :provider_source_id),
          status: :active,
          title: "Telegram Space"
        },
        authorize?: false,
        domain: Wik.Access
      )

    identity =
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

    Ash.create!(
      Grant,
      %{
        external_identity_id: identity.id,
        last_verified_at: Keyword.fetch!(opts, :last_verified_at),
        source_id: source.id,
        status: :active,
        user_id: user.id
      },
      authorize?: false,
      domain: Wik.Access
    )
  end
end
