defmodule Wik.Events.Feeds.Token do
  alias Wik.Accounts.Group
  alias Wik.Accounts.User
  alias WikWeb.Endpoint

  @salt "calendar_feed"

  def issue_aggregate(%User{id: user_id}) do
    Phoenix.Token.encrypt(
      Endpoint,
      @salt,
      %{feed_kind: :aggregate, user_id: user_id},
      max_age: :infinity
    )
  end

  def issue_group(%User{id: user_id}, %Group{id: group_id}) do
    Phoenix.Token.encrypt(
      Endpoint,
      @salt,
      %{feed_kind: :group, group_id: group_id, user_id: user_id},
      max_age: :infinity
    )
  end

  def decode(token) do
    case Phoenix.Token.decrypt(Endpoint, @salt, token, max_age: :infinity) do
      {:ok, %{feed_kind: :aggregate, user_id: user_id} = payload} when is_binary(user_id) ->
        {:ok, payload}

      {:ok, %{feed_kind: :group, group_id: group_id, user_id: user_id} = payload}
      when is_binary(group_id) and is_binary(user_id) ->
        {:ok, payload}

      {:ok, _payload} ->
        {:error, :invalid}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
