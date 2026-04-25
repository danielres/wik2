defmodule QblogWeb.Webhooks.TelegramController do
  use QblogWeb, :controller

  alias Qblog.Access
  alias Qblog.Access.Providers.Telegram
  alias QblogWeb.Context

  require Logger

  def create(conn, params) do
    :ok = store_bot_update(params)

    case Telegram.source_attrs_from_update(params) do
      {:ok, source_attrs} ->
        source_attrs
        |> Access.telegram_upsert_pending_source()
        |> broadcast_claimable_sources_changed(params)
        |> respond(conn)

      :ignore ->
        json(conn, %{ok: true})
    end
  end

  defp respond({:ok, _source}, conn) do
    json(conn, %{ok: true})
  end

  defp respond({:error, error}, conn) do
    Logger.error("Telegram webhook failed: #{inspect(error)}")

    conn
    |> put_status(:unprocessable_entity)
    |> json(%{ok: false})
  end

  defp store_bot_update(params) do
    case Access.telegram_create_bot_update(params) do
      {:ok, _bot_update} ->
        :ok

      {:error, error} ->
        Logger.error("Telegram bot update storage failed: #{inspect(error)}")
        :ok
    end
  end

  defp broadcast_claimable_sources_changed({:ok, _source} = result, params) do
    with {:ok, telegram_user_id} <- telegram_actor_id(params),
         {:ok, user_id} <- Access.get_telegram_user_id_by_provider_user_id(telegram_user_id),
         user_id when not is_nil(user_id) <- user_id do
      :ok = Context.broadcast_claimable_sources_changed(user_id)
    end

    result
  end

  defp broadcast_claimable_sources_changed(result, _params), do: result

  defp telegram_actor_id(%{"my_chat_member" => %{"from" => %{"id" => telegram_user_id}}}) do
    {:ok, to_string(telegram_user_id)}
  end

  defp telegram_actor_id(_params), do: :ignore
end
