defmodule WikWeb.PresenceTest do
  use Wik.DataCase, async: false

  import Wik.TestGenerators

  alias Wik.Access.ExternalIdentity
  alias Wik.Access.Grant
  alias Wik.Access.Source

  test "tracking a new presence records when the member connected to the space" do
    user = generate(user(email: "seen@example.com"))
    space = generate(space())
    membership = add_membership(space, user, :member)

    assert membership.last_seen_at == nil

    assert {:ok, _meta} =
             WikWeb.Presence.track_user_presence(user, "/#{space.slug}/wiki/home", space.id)

    membership = Ash.get!(Wik.Accounts.Membership, membership.id, authorize?: false)

    assert %DateTime{} = membership.last_seen_at
    assert DateTime.diff(DateTime.utc_now(), membership.last_seen_at, :second) < 5
  end

  test "fetch enriches presence entries with user data" do
    zoe = generate(user(email: "zoe@example.com"))
    anna = generate(user(email: "anna@example.com"))

    presences = %{
      zoe.id => %{metas: [%{space_id: "space-1", path: "/space-1/wiki/home"}]},
      anna.id => %{metas: [%{space_id: "space-1", path: "/space-1/blog"}]}
    }

    fetched_presences = WikWeb.Presence.fetch("space:space-1:users", presences)

    assert %{id: zoe_user_id, metas: [%{path: "/space-1/wiki/home"}], user: fetched_zoe} =
             Map.fetch!(fetched_presences, zoe.id)

    assert %{id: anna_user_id, metas: [%{path: "/space-1/blog"}], user: fetched_anna} =
             Map.fetch!(fetched_presences, anna.id)

    assert zoe_user_id == zoe.id
    assert anna_user_id == anna.id
    assert fetched_zoe.id == zoe.id
    assert fetched_anna.id == anna.id
  end

  test "fetch enriches presence entries with grant avatar urls" do
    user = generate(user(email: "zoe@example.com"))
    space = generate(space())
    add_membership(space, user, :member)
    create_telegram_access(space, user)

    presences = %{
      user.id => %{metas: [%{space_id: space.id, path: "/#{space.slug}/wiki/home"}]}
    }

    fetched_presences = WikWeb.Presence.fetch("space:#{space.id}:users", presences)

    assert %{membership: %{avatar_url: "https://telegram.example/avatar.png"}} =
             Map.fetch!(fetched_presences, user.id)
  end

  test "fetch enriches presence entries with membership usernames" do
    user = generate(user(email: "zoe@example.com"))
    space = generate(space())
    add_membership(space, user, :member, username: "zoe-space")

    presences = %{
      user.id => %{metas: [%{space_id: space.id, path: "/#{space.slug}/wiki/home"}]}
    }

    fetched_presences = WikWeb.Presence.fetch("space:#{space.id}:users", presences)

    assert %{membership: %{username: "zoe-space"}} = Map.fetch!(fetched_presences, user.id)
  end

  test "users_at_path returns the usernames for a given path" do
    home_user = generate(user(email: "home@example.com"))
    tree_user = generate(user(email: "tree@example.com"))

    presences = [
      %{
        display_name: "home-space",
        id: home_user.id,
        membership: %{display_name: "home-space", user: home_user, username: "home-space"},
        metas: [%{path: "/space-1/wiki/home"}],
        user: home_user,
        username: "home-space"
      },
      %{
        display_name: "tree-space",
        id: tree_user.id,
        membership: %{display_name: "tree-space", user: tree_user, username: "tree-space"},
        metas: [%{path: "/space-1/tree"}],
        user: tree_user,
        username: "tree-space"
      }
    ]

    assert ["tree-space"] = WikWeb.Presence.users_at_path(presences, "/space-1/tree")
  end

  test "presences_to_locks ignores the current tab and keeps locks from other tabs" do
    current_user = generate(user(email: "current@example.com"))
    other_user = generate(user(email: "other@example.com"))
    current_user_id = current_user.id
    other_user_id = other_user.id

    presences = [
      %{
        id: current_user.id,
        membership: %{
          avatar_url: "https://telegram.example/current.png",
          display_name: "current-space",
          user: current_user,
          username: "current-space"
        },
        metas: [
          %{
            editing_block_id: "block-a",
            path: "/space-1/wiki/home",
            tab_id: "tab-1"
          },
          %{editing_block_id: "block-c", path: "/space-1/blog", tab_id: "tab-2"}
        ],
        user: current_user
      },
      %{
        id: other_user.id,
        membership: %{
          avatar_url: "https://telegram.example/other.png",
          display_name: "other-space",
          user: other_user,
          username: "other-space"
        },
        metas: [
          %{editing_block_id: "block-a", path: "/space-1/wiki/home", tab_id: "tab-3"},
          %{editing_block_id: "block-b", path: "/space-1/tree", tab_id: "tab-4"}
        ],
        user: other_user
      }
    ]

    assert %{
             "block-a" => %{
               block_id: "block-a",
               membership: %{
                 avatar_url: "https://telegram.example/other.png",
                 display_name: "other-space",
                 user: ^other_user,
                 username: "other-space"
               },
               user: ^other_user,
               user_id: ^other_user_id
             },
             "block-b" => %{
               block_id: "block-b",
               membership: %{
                 avatar_url: "https://telegram.example/other.png",
                 display_name: "other-space",
                 user: ^other_user,
                 username: "other-space"
               },
               user: ^other_user,
               user_id: ^other_user_id
             },
             "block-c" => %{
               block_id: "block-c",
               membership: %{
                 avatar_url: "https://telegram.example/current.png",
                 display_name: "current-space",
                 user: ^current_user,
                 username: "current-space"
               },
               user: ^current_user,
               user_id: ^current_user_id
             }
           } = WikWeb.Presence.presences_to_locks(presences, current_user.id, "tab-1")
  end

  defp add_membership(space, user, type, opts \\ []) do
    membership =
      Ash.create!(
        Wik.Accounts.Membership,
        %{
          space_id: space.id,
          type: type,
          user_id: user.id
        },
        authorize?: false,
        domain: Wik.Accounts
      )

    case Keyword.get(opts, :username) do
      nil ->
        membership

      username ->
        Ash.update!(
          membership,
          %{username: username},
          action: :set_username,
          scope: %Wik.Scope{actor: user, tenant: space}
        )
    end
  end

  defp create_telegram_access(space, user) do
    source =
      Ash.create!(
        Source,
        %{
          claimed_at: DateTime.utc_now(),
          claimed_by_user_id: user.id,
          space_id: space.id,
          provider: :telegram,
          provider_source_id: "telegram-source-#{System.unique_integer([:positive])}",
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
          avatar_url: "https://telegram.example/avatar.png",
          display_name: "Zoe",
          provider: :telegram,
          provider_user_id: "telegram-user-#{System.unique_integer([:positive])}",
          user_id: user.id,
          username: "zoe"
        },
        authorize?: false,
        domain: Wik.Access
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
      domain: Wik.Access
    )
  end
end
