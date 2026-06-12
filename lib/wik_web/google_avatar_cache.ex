defmodule WikWeb.GoogleAvatarCache do
  @moduledoc false

  alias WikWeb.Endpoint

  @salt "google_avatar_cache"
  @max_age 60 * 60 * 24 * 365 * 20

  def cached_url(url) when is_binary(url) do
    if google_avatar_url?(url) do
      token = Phoenix.Token.encrypt(Endpoint, @salt, url, max_age: @max_age)
      "/avatars/google/#{token}"
    else
      url
    end
  end

  def cached_url(url), do: url

  def decode_token(token) when is_binary(token) do
    with {:ok, url} when is_binary(url) <-
           Phoenix.Token.decrypt(Endpoint, @salt, token, max_age: @max_age),
         true <- google_avatar_url?(url) do
      {:ok, url}
    else
      _error -> {:error, :invalid}
    end
  end

  def refresh(url, opts \\ [])

  def refresh(url, opts) when is_binary(url) do
    if google_avatar_url?(url) do
      do_refresh(url, opts)
    else
      {:error, :invalid_url}
    end
  end

  def refresh(_url, _opts), do: {:error, :invalid_url}

  def read_cached(url) when is_binary(url) do
    file = image_path(url)
    metadata_file = metadata_path(url)

    with true <- File.exists?(file),
         {:ok, content_type} <- File.read(metadata_file) do
      {:ok, %{content_type: content_type, path: file}}
    else
      _error -> {:error, :not_found}
    end
  end

  def read_cached(_url), do: {:error, :not_found}

  def cache_dir do
    Application.get_env(:wik, __MODULE__, [])
    |> Keyword.get(:cache_dir, Path.join(System.tmp_dir!(), "wik-google-avatars"))
  end

  defp do_refresh(url, opts) do
    case fetch(url, opts) do
      {:ok, %{body: body, content_type: content_type}} ->
        write_cache(url, body, content_type)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch(url, opts) do
    http_get = Keyword.get(opts, :http_get, http_get())

    case http_get.(url, []) do
      {:ok, %Req.Response{status: 200, body: body} = response} when is_binary(body) ->
        content_type = response_content_type(response)

        if image_content_type?(content_type) do
          {:ok, %{body: body, content_type: content_type}}
        else
          {:error, :invalid_content_type}
        end

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_status, status}}

      {:error, reason} ->
        {:error, reason}

      _response ->
        {:error, :invalid_response}
    end
  end

  defp write_cache(url, body, content_type) do
    dir = cache_dir()
    image_file = image_path(url)
    metadata_file = metadata_path(url)

    with :ok <- File.mkdir_p(dir),
         :ok <- File.write(image_file, body),
         :ok <- File.write(metadata_file, content_type) do
      {:ok, %{content_type: content_type, path: image_file}}
    end
  end

  defp http_get do
    Application.get_env(:wik, __MODULE__, [])
    |> Keyword.get(:http_get, &Req.get/2)
  end

  defp google_avatar_url?(url) do
    uri = URI.parse(url)

    uri.scheme == "https" and googleusercontent_host?(uri.host)
  end

  defp googleusercontent_host?(host) when is_binary(host) do
    host == "googleusercontent.com" or String.ends_with?(host, ".googleusercontent.com")
  end

  defp googleusercontent_host?(_host), do: false

  defp image_path(url), do: Path.join(cache_dir(), "#{url_cache_key(url)}.image")
  defp metadata_path(url), do: Path.join(cache_dir(), "#{url_cache_key(url)}.content-type")

  defp url_cache_key(url) do
    :sha256
    |> :crypto.hash(url)
    |> Base.url_encode64(padding: false)
  end

  defp response_content_type(response) do
    response
    |> Req.Response.get_header("content-type")
    |> List.first()
    |> content_type_media_type()
  end

  defp content_type_media_type(nil), do: nil

  defp content_type_media_type(content_type) do
    content_type
    |> String.split(";", parts: 2)
    |> List.first()
    |> String.trim()
    |> String.downcase()
  end

  defp image_content_type?(content_type) when is_binary(content_type) do
    String.starts_with?(content_type, "image/")
  end

  defp image_content_type?(_content_type), do: false
end
