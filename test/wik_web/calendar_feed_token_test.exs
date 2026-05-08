defmodule Wik.Events.Feeds.TokenTest do
  use ExUnit.Case, async: true

  alias Wik.Events.Feeds.Token

  test "decodes an aggregate feed token" do
    user = %Wik.Accounts.User{id: "user-1"}

    token = Token.issue_aggregate(user)

    assert {:ok, %{feed_kind: :aggregate, user_id: user_id}} = Token.decode(token)
    assert user_id == user.id
  end

  test "decodes a group feed token" do
    user = %Wik.Accounts.User{id: "user-1"}
    group = %Wik.Accounts.Group{id: "group-1"}

    token = Token.issue_group(user, group)

    assert {:ok, %{feed_kind: :group, group_id: group_id, user_id: user_id}} =
             Token.decode(token)

    assert group_id == group.id
    assert user_id == user.id
  end

  test "rejects a tampered token" do
    user = %Wik.Accounts.User{id: "user-1"}
    token = Token.issue_aggregate(user)
    tampered = token <> "tampered"

    assert {:error, :invalid} = Token.decode(tampered)
  end
end
