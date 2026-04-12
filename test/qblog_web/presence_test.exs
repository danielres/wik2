defmodule QblogWeb.PresenceTest do
  use Qblog.DataCase, async: false

  import Qblog.TestGenerators

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

  test "users_at_path returns the usernames for a given path" do
    home_user = generate(user(email: "home@example.com"))
    tree_user = generate(user(email: "tree@example.com"))

    presences = [
      %{id: home_user.id, metas: [%{path: "/group-1/wiki/home"}], user: home_user},
      %{id: tree_user.id, metas: [%{path: "/group-1/tree"}], user: tree_user}
    ]

    assert ["tree"] = QblogWeb.Presence.users_at_path(presences, "/group-1/tree")
  end
end
