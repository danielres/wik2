defmodule Wik.Events.Feeds.TokenTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.Space
  alias Wik.Accounts.Token, as: StoredToken
  alias Wik.Events.Feeds.Token

  test "decodes an aggregate feed token" do
    user = %Wik.Accounts.User{id: "user-1"}

    token = Token.issue_for_aggregate(user)

    assert {:ok, %{feed_kind: :aggregate, user_id: user_id}} = Token.decode(token)
    assert user_id == user.id
  end

  test "decodes a space feed token" do
    user = %Wik.Accounts.User{id: "user-1"}
    space = %Wik.Accounts.Space{id: "space-1"}

    token = Token.issue_for_space(user, space)

    assert {:ok, %{feed_kind: :space, space_id: space_id, user_id: user_id}} =
             Token.decode(token)

    assert space_id == space.id
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
    space = %Space{id: Ecto.UUID.generate()}

    token = Token.issue_for_aggregate(user)
    additional_token = store_token(user, "calendar_feed:aggregate")
    space_token = Token.issue_for_space(user, space)

    assert :ok = Token.revoke_for_aggregate(user)
    assert {:error, :revoked} = Token.decode(token)
    assert_stored_token_purpose(additional_token, "revoked:calendar_feed:aggregate")
    assert {:ok, %{feed_kind: :space}} = Token.decode(space_token)

    replacement = Token.issue_for_aggregate(user)

    assert replacement != token
    assert {:ok, %{feed_kind: :aggregate, user_id: user_id}} = Token.decode(replacement)
    assert user_id == user.id
  end

  test "revoking an aggregate feed without stored tokens succeeds" do
    assert :ok = Token.revoke_for_aggregate(generate(user()))
  end

  defp assert_stored_token_purpose(stored_token, purpose) do
    assert {:ok, stored_token} = Ash.get(StoredToken, stored_token.jti, authorize?: false)
    assert stored_token.purpose == purpose
  end

  defp store_token(user, purpose) do
    Ash.create!(
      StoredToken,
      %{
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        extra_data: %{},
        jti: Ecto.UUID.generate(),
        purpose: purpose,
        subject: "user?id=#{user.id}"
      },
      action: :store_custom_token,
      authorize?: false
    )
  end
end
