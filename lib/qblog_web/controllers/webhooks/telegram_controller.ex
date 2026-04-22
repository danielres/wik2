defmodule QblogWeb.Webhooks.TelegramController do
  use QblogWeb, :controller

  alias Qblog.Access
  alias Qblog.Access.Providers.Telegram

  require Logger

  def create(conn, params) do
    :ok = store_bot_update(params)

    case Telegram.source_attrs_from_update(params) do
      {:ok, source_attrs} ->
        source_attrs |> Access.telegram_upsert_pending_source() |> respond(conn)

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
end
