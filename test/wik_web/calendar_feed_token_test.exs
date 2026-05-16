defmodule Wik.Events.Feeds.TokenTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Events.Feeds.Token

  test "decodes an aggregate feed token" do
    user = %Wik.Accounts.User{id: "user-1"}

    token = Token.issue_for_aggregate(user)

    assert {:ok, %{feed_kind: :aggregate, user_id: user_id}} = Token.decode(token)
    assert user_id == user.id
  end

  test "decodes a group feed token" do
    user = %Wik.Accounts.User{id: "user-1"}
    group = %Wik.Accounts.Group{id: "group-1"}

    token = Token.issue_for_group(user, group)

    assert {:ok, %{feed_kind: :group, group_id: group_id, user_id: user_id}} =
             Token.decode(token)

    assert group_id == group.id
    assert user_id == user.id
  end

  test "rejects a tampered token" do
    user = %Wik.Accounts.User{id: "user-1"}
    token = Token.issue_for_aggregate(user)
    tampered = token <> "tampered"

    assert {:error, :invalid} = Token.decode(tampered)
  end

  test "revokes an aggregate feed token and issues a different replacement token" do
    user = generate(user())

    token = Token.issue_for_aggregate(user)

    assert :ok = Token.revoke_for_aggregate(user)
    assert {:error, :revoked} = Token.decode(token)

    replacement = Token.issue_for_aggregate(user)

    assert replacement != token
    assert {:ok, %{feed_kind: :aggregate, user_id: user_id}} = Token.decode(replacement)
    assert user_id == user.id
  end
end
