defmodule WikWeb.LibraryLive.ExternalMedia do
  @moduledoc false

  require Logger

  alias WikWeb.LibraryLive.ExternalMedia.SoundCloud
  alias WikWeb.LibraryLive.ExternalMedia.YouTube

  def resolve(url, opts \\ [])

  def resolve(url, opts) when is_binary(url) do
    opts = Keyword.merge(Application.get_env(:wik, __MODULE__, []), opts)

    case provider(url) do
      :youtube -> resolve_with(:youtube, YouTube, url, opts)
      :soundcloud -> resolve_with(:soundcloud, SoundCloud, url, opts)
      nil -> {:error, :unsupported_provider}
    end
  end

  def resolve(_url, _opts), do: {:error, :unsupported_provider}

  defp resolve_with(provider, resolver, url, opts) do
    case resolver.resolve(url, opts) do
      {:error, :unsupported_provider} = error ->
        error

      {:error, reason} ->
        Logger.warning(
          "External media details could not be loaded: " <>
            "provider=#{provider} reason=#{inspect(reason)}"
        )

        {:error, :unavailable}

      result ->
        result
    end
  end

  defp provider(url) do
    case URI.parse(String.trim(url)) do
      %URI{scheme: "https", host: host}
      when host in [
             "m.youtube.com",
             "www.youtube.com",
             "www.youtube-nocookie.com",
             "www.youtu.be",
             "youtube.com",
             "youtube-nocookie.com",
             "youtu.be"
           ] ->
        :youtube

      %URI{scheme: "https", host: host} when host in ["soundcloud.com", "www.soundcloud.com"] ->
        :soundcloud

      _uri ->
        nil
    end
  end
end
