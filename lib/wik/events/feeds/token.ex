defmodule Wik.Events.Feeds.Token do
  import Ash.Expr

  require Ash.Query
  alias Wik.Accounts.Group
  alias Wik.Accounts.Token, as: StoredToken
  alias Wik.Accounts.User
  alias WikWeb.Endpoint

  @salt "calendar_feed"
  @max_age 60 * 60 * 24 * 365 * 20

  defp aggregate_purpose, do: "calendar_feed:aggregate"
  defp group_purpose(group_id), do: "calendar_feed:group:#{group_id}"
  defp feed_subject(user_id), do: "user?id=#{user_id}"

  def issue_for_aggregate(%User{id: user_id}) do
    issue_token(
      %{feed_kind: :aggregate, user_id: user_id},
      feed_subject(user_id),
      aggregate_purpose()
    )
  end

  def issue_for_group(%User{id: user_id}, %Group{id: group_id}) do
    issue_token(
      %{feed_kind: :group, group_id: group_id, user_id: user_id},
      feed_subject(user_id),
      group_purpose(group_id)
    )
  end

  def decode(token) do
    with {:ok, payload} <- decode_payload(token),
         false <- revoked?(payload.jti) do
      {:ok, Map.delete(payload, :jti)}
    else
      true -> {:error, :revoked}
      {:error, reason} -> {:error, reason}
    end
  end

  # TODO: implement UI
  def revoke_for_aggregate(%User{id: user_id}) do
    revoke_tokens_for_subject_and_purpose(feed_subject(user_id), aggregate_purpose())
  end

  # TODO: implement UI
  def revoke_for_group(%User{id: user_id}, %Group{id: group_id}) do
    revoke_tokens_for_subject_and_purpose(feed_subject(user_id), group_purpose(group_id))
  end

  defp decode_payload(token) do
    case Phoenix.Token.decrypt(Endpoint, @salt, token, max_age: @max_age) do
      {:ok, %{feed_kind: :aggregate, jti: jti, user_id: user_id} = payload}
      when is_binary(jti) and is_binary(user_id) ->
        {:ok, payload}

      {:ok, %{feed_kind: :group, group_id: group_id, jti: jti, user_id: user_id} = payload}
      when is_binary(group_id) and is_binary(jti) and is_binary(user_id) ->
        {:ok, payload}

      {:ok, _payload} ->
        {:error, :invalid}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp issue_token(payload, subject, purpose) do
    case lookup_active_token(subject, purpose) do
      {:ok, token} ->
        token

      :error ->
        mint_token(payload, subject, purpose)
    end
  end

  defp lookup_active_token(subject, purpose) do
    StoredToken
    |> Ash.Query.filter(expr(subject == ^subject and purpose == ^purpose))
    |> Ash.Query.sort(created_at: :desc)
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, stored_tokens} ->
        case find_active_token_value(stored_tokens) do
          nil -> :error
          token -> {:ok, token}
        end

      {:error, _error} ->
        :error
    end
  end

  defp find_active_token_value(stored_tokens) do
    Enum.find_value(stored_tokens, fn
      %StoredToken{extra_data: %{"token" => token}, jti: jti}
      when is_binary(token) and is_binary(jti) ->
        case decode_payload(token) do
          {:ok, %{jti: ^jti}} -> token
          _ -> nil
        end

      _stored_token ->
        nil
    end)
  end

  defp mint_token(payload, subject, purpose) do
    jti = Ecto.UUID.generate()

    token =
      Phoenix.Token.encrypt(
        Endpoint,
        @salt,
        Map.put(payload, :jti, jti),
        max_age: @max_age
      )

    expires_at = DateTime.add(DateTime.utc_now(), @max_age, :second)

    case Ash.create(
           StoredToken,
           %{
             expires_at: expires_at,
             extra_data: %{"token" => token},
             jti: jti,
             purpose: purpose,
             subject: subject
           },
           action: :store_custom_token,
           authorize?: false
         ) do
      {:ok, _stored_token} -> token
      {:error, error} -> raise "failed to store calendar feed token: #{inspect(error)}"
    end
  end

  defp revoked?(jti) do
    case Ash.get(StoredToken, jti, authorize?: false) do
      {:ok, %StoredToken{purpose: purpose}} -> String.starts_with?(purpose, "revoked:")
      {:error, _error} -> true
    end
  end

  defp revoke_tokens_for_subject_and_purpose(subject, purpose) do
    StoredToken
    |> Ash.Query.filter(expr(subject == ^subject and purpose == ^purpose))
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, stored_tokens} ->
        stored_tokens
        |> Enum.reduce_while(:ok, fn stored_token, :ok ->
          case Ash.update(stored_token, %{},
                 action: :revoke_custom_token,
                 authorize?: false
               ) do
            {:ok, _stored_token} -> {:cont, :ok}
            {:error, error} -> {:halt, {:error, error}}
          end
        end)

      {:error, error} ->
        {:error, error}
    end
  end
end
