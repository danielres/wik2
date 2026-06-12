defmodule WikWeb.GoogleAvatarControllerTest do
  use WikWeb.ConnCase

  alias WikWeb.GoogleAvatarCache

  setup do
    previous_env = Application.get_env(:wik, GoogleAvatarCache)

    cache_dir =
      Path.join(System.tmp_dir!(), "wik-google-avatar-test-#{System.unique_integer([:positive])}")

    Application.put_env(:wik, GoogleAvatarCache, cache_dir: cache_dir)

    on_exit(fn ->
      File.rm_rf(cache_dir)
      restore_env(previous_env)
    end)

    %{cache_dir: cache_dir}
  end

  test "fetches and serves a valid google avatar", %{conn: conn, cache_dir: cache_dir} do
    put_cache_env(cache_dir,
      http_get: fn "https://lh3.googleusercontent.com/a/avatar=s96-c", [] ->
        {:ok,
         Req.Response.new(
           status: 200,
           body: "image-bytes",
           headers: [{"content-type", "image/png"}]
         )}
      end
    )

    conn = get(conn, google_avatar_path("https://lh3.googleusercontent.com/a/avatar=s96-c"))

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["image/png; charset=utf-8"]
    assert conn.resp_body == "image-bytes"
  end

  test "serves a cached google avatar without refetching", %{conn: conn, cache_dir: cache_dir} do
    counter = start_supervised!({Agent, fn -> 0 end})

    put_cache_env(cache_dir,
      http_get: fn "https://lh3.googleusercontent.com/a/cached=s96-c", [] ->
        Agent.update(counter, &(&1 + 1))

        {:ok,
         Req.Response.new(
           status: 200,
           body: "cached-image-bytes",
           headers: [{"content-type", "image/jpeg"}]
         )}
      end
    )

    path = google_avatar_path("https://lh3.googleusercontent.com/a/cached=s96-c")

    first_conn = get(conn, path)
    second_conn = conn |> recycle() |> get(path)

    assert first_conn.status == 200
    assert first_conn.resp_body == "cached-image-bytes"
    assert second_conn.status == 200
    assert second_conn.resp_body == "cached-image-bytes"
    assert Agent.get(counter, & &1) == 1
  end

  test "returns not found for an invalid token", %{conn: conn} do
    conn = get(conn, ~p"/avatars/google/not-a-valid-token")

    assert conn.status == 404
  end

  test "returns not found for a signed non-google url", %{conn: conn} do
    token =
      Phoenix.Token.encrypt(
        WikWeb.Endpoint,
        "google_avatar_cache",
        "https://example.com/avatar.png"
      )

    path = "/avatars/google/#{token}"

    conn = get(conn, path)

    assert conn.status == 404
  end

  test "does not overwrite an existing cached avatar after a failed refresh", %{
    cache_dir: cache_dir
  } do
    url = "https://lh3.googleusercontent.com/a/fallback=s96-c"

    assert {:ok, %{path: path}} =
             GoogleAvatarCache.refresh(url,
               http_get: fn ^url, [] ->
                 {:ok,
                  Req.Response.new(
                    status: 200,
                    body: "old-image",
                    headers: [{"content-type", "image/png"}]
                  )}
               end
             )

    put_cache_env(cache_dir,
      http_get: fn ^url, [] ->
        {:ok, Req.Response.new(status: 429, body: "too many requests")}
      end
    )

    assert {:error, {:http_status, 429}} = GoogleAvatarCache.refresh(url)
    assert File.read!(path) == "old-image"
    assert {:ok, %{content_type: "image/png", path: ^path}} = GoogleAvatarCache.read_cached(url)
  end

  test "returns unavailable when upstream fails and no cache exists", %{
    conn: conn,
    cache_dir: cache_dir
  } do
    put_cache_env(cache_dir,
      http_get: fn "https://lh3.googleusercontent.com/a/missing=s96-c", [] ->
        {:ok, Req.Response.new(status: 429, body: "too many requests")}
      end
    )

    conn = get(conn, google_avatar_path("https://lh3.googleusercontent.com/a/missing=s96-c"))

    assert conn.status == 502
  end

  test "rejects non-image upstream responses", %{conn: conn, cache_dir: cache_dir} do
    put_cache_env(cache_dir,
      http_get: fn "https://lh3.googleusercontent.com/a/html=s96-c", [] ->
        {:ok,
         Req.Response.new(
           status: 200,
           body: "<html></html>",
           headers: [{"content-type", "text/html"}]
         )}
      end
    )

    conn = get(conn, google_avatar_path("https://lh3.googleusercontent.com/a/html=s96-c"))

    assert conn.status == 502
  end

  defp google_avatar_path(url), do: GoogleAvatarCache.cached_url(url)

  defp put_cache_env(cache_dir, overrides) do
    Application.put_env(:wik, GoogleAvatarCache, Keyword.put(overrides, :cache_dir, cache_dir))
  end

  defp restore_env(nil), do: Application.delete_env(:wik, GoogleAvatarCache)
  defp restore_env(env), do: Application.put_env(:wik, GoogleAvatarCache, env)
end
