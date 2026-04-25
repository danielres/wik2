defmodule Qblog.Access.GroupAvatarUrlTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Access
  alias Qblog.Access.ExternalIdentity
  alias Qblog.Access.Grant
  alias Qblog.Access.Source

  test "returns the first non-nil avatar url for a user's grants in a group" do
    user = generate(user())
    group = generate(group())

    source_without_avatar =
      create_source(group, user, "source-without-avatar")

    identity_without_avatar =
      create_identity(user,
        provider_user_id: "telegram-user-without-avatar",
        avatar_url: nil
      )

    older = DateTime.utc_now() |> DateTime.add(-60, :second)
    newer = DateTime.utc_now()

    create_grant(source_without_avatar, identity_without_avatar, user, newer)

    source_with_avatar =
      create_source(group, user, "source-with-avatar")

    identity_with_avatar =
      create_identity(user,
        provider_user_id: "telegram-user-with-avatar",
        avatar_url: "https://telegram.example/avatar.png"
      )

    create_grant(source_with_avatar, identity_with_avatar, user, older)

    assert {:ok, "https://telegram.example/avatar.png"} =
             Access.get_user_group_avatar_url(user, group)
  end

  defp create_source(group, user, provider_source_id) do
    Ash.create!(
      Source,
      %{
        claimed_at: DateTime.utc_now(),
        claimed_by_user_id: user.id,
        group_id: group.id,
        provider: :telegram,
        provider_source_id: provider_source_id,
        status: :active,
        title: "Telegram Group"
      },
      authorize?: false,
      domain: Qblog.Access
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
      domain: Qblog.Access
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
      domain: Qblog.Access
    )
  end
end
