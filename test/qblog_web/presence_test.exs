defmodule QblogWeb.PresenceTest do
  use Qblog.DataCase, async: false

  import Qblog.TestGenerators

  alias Qblog.Access.ExternalIdentity
  alias Qblog.Access.Grant
  alias Qblog.Access.Source

  test "fetch enriches presence entries with user data" do
    zoe = generate(user(email: "zoe@example.com"))
    anna = generate(user(email: "anna@example.com"))

    presences = %{
      zoe.id => %{metas: [%{group_id: "group-1", path: "/group-1/wiki/home"}]},
      anna.id => %{metas: [%{group_id: "group-1", path: "/group-1/blog"}]}
    }

    fetched_presences = QblogWeb.Presence.fetch("group:group-1:users", presences)

    assert %{id: zoe_user_id, metas: [%{path: "/group-1/wiki/home"}], user: fetched_zoe} =
             Map.fetch!(fetched_presences, zoe.id)

    assert %{id: anna_user_id, metas: [%{path: "/group-1/blog"}], user: fetched_anna} =
             Map.fetch!(fetched_presences, anna.id)

    assert zoe_user_id == zoe.id
    assert anna_user_id == anna.id
    assert fetched_zoe.id == zoe.id
    assert fetched_anna.id == anna.id
  end

  test "fetch enriches presence entries with grant avatar urls" do
    user = generate(user(email: "zoe@example.com"))
    group = generate(group())
    create_telegram_access(group, user)

    presences = %{
      user.id => %{metas: [%{group_id: group.id, path: "/#{group.name}/wiki/home"}]}
    }

    fetched_presences = QblogWeb.Presence.fetch("group:#{group.id}:users", presences)

    assert %{avatar_url: "https://telegram.example/avatar.png"} =
             Map.fetch!(fetched_presences, user.id)
  end

  test "users_at_path returns the usernames for a given path" do
    home_user = generate(user(email: "home@example.com"))
    tree_user = generate(user(email: "tree@example.com"))

    presences = [
      %{id: home_user.id, metas: [%{path: "/group-1/wiki/home"}], user: home_user},
      %{id: tree_user.id, metas: [%{path: "/group-1/tree"}], user: tree_user}
    ]

    assert ["tree"] = QblogWeb.Presence.users_at_path(presences, "/group-1/tree")
  end

  test "presences_to_locks ignores the current tab and keeps locks from other tabs" do
    current_user = generate(user(email: "current@example.com"))
    other_user = generate(user(email: "other@example.com"))
    current_user_id = current_user.id
    other_user_id = other_user.id

    presences = [
      %{
        id: current_user.id,
        metas: [
          %{
            editing_block_id: "block-a",
            path: "/group-1/wiki/home",
            tab_id: "tab-1"
          },
          %{editing_block_id: "block-c", path: "/group-1/blog", tab_id: "tab-2"}
        ],
        user: current_user
      },
      %{
        id: other_user.id,
        metas: [
          %{editing_block_id: "block-a", path: "/group-1/wiki/home", tab_id: "tab-3"},
          %{editing_block_id: "block-b", path: "/group-1/tree", tab_id: "tab-4"}
        ],
        user: other_user
      }
    ]

    assert %{
             "block-a" => %{block_id: "block-a", user: ^other_user, user_id: ^other_user_id},
             "block-b" => %{block_id: "block-b", user: ^other_user, user_id: ^other_user_id},
             "block-c" => %{block_id: "block-c", user: ^current_user, user_id: ^current_user_id}
           } = QblogWeb.Presence.presences_to_locks(presences, current_user.id, "tab-1")
  end

  defp create_telegram_access(group, user) do
    source =
      Ash.create!(
        Source,
        %{
          claimed_at: DateTime.utc_now(),
          claimed_by_user_id: user.id,
          group_id: group.id,
          provider: :telegram,
          provider_source_id: "telegram-source-#{System.unique_integer([:positive])}",
          status: :active,
          title: "Telegram Group"
        },
        authorize?: false,
        domain: Qblog.Access
      )

    identity =
      Ash.create!(
        ExternalIdentity,
        %{
          avatar_url: "https://telegram.example/avatar.png",
          display_name: "Zoe",
          provider: :telegram,
          provider_user_id: "telegram-user-#{System.unique_integer([:positive])}",
          user_id: user.id,
          username: "zoe"
        },
        authorize?: false,
        domain: Qblog.Access
      )

    Ash.create!(
      Grant,
      %{
        external_identity_id: identity.id,
        last_verified_at: DateTime.utc_now(),
        source_id: source.id,
        status: :active,
        user_id: user.id
      },
      authorize?: false,
      domain: Qblog.Access
    )
  end
end
