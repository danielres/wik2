defmodule WikWeb.GoogleAvatarController do
  use WikWeb, :controller

  alias WikWeb.GoogleAvatarCache

  def show(conn, %{"token" => token}) do
    with {:ok, url} <- GoogleAvatarCache.decode_token(token),
         {:ok, cached_avatar} <- get_or_refresh(url) do
      conn
      |> put_resp_content_type(cached_avatar.content_type)
      |> put_resp_header("cache-control", "public, max-age=86400")
      |> send_file(200, cached_avatar.path)
    else
      {:error, :invalid} ->
        send_resp(conn, 404, "Not found")

      {:error, :not_found} ->
        send_resp(conn, 502, "Avatar unavailable")

      {:error, _reason} ->
        send_resp(conn, 502, "Avatar unavailable")
    end
  end

  defp get_or_refresh(url) do
    case GoogleAvatarCache.read_cached(url) do
      {:ok, cached_avatar} -> {:ok, cached_avatar}
      {:error, :not_found} -> GoogleAvatarCache.refresh(url)
    end
  end
end
