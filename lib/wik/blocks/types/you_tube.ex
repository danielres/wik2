defmodule Wik.Blocks.Types.YouTube do
  @behaviour Wik.Blocks.Types.Behaviour

  alias Wik.Blocks.Types.Embed

  def label, do: "YouTube"
  def type, do: :youtube
  def supports_history?, do: false
  def supports_title?, do: true

  defdelegate create_initial_version(block, opts), to: Embed
  defdelegate default_data(), to: Embed
  defdelegate block_to_form_params(block, params, page_tree), to: Embed
  defdelegate version_to_text(block, version, opts), to: Embed

  def update_block(block, params, opts) do
    Embed.update_block(block, params, opts, &normalize_embed_input/1)
  end

  def validate_data(data) do
    with :ok <- Embed.validate_title(data) do
      url = data |> get_url()

      case url do
        nil ->
          :ok

        "" ->
          :ok

        url when is_binary(url) ->
          if embed_url?(url) do
            :ok
          else
            {:error, field: :data, message: "youtube blocks must store a YouTube embed URL"}
          end

        _ ->
          {:error, field: :data, message: "youtube blocks must store a YouTube embed URL"}
      end
    end
  end

  def normalize_embed_input(nil), do: {:ok, ""}

  def normalize_embed_input(input) when is_binary(input) do
    input = input |> String.trim()

    cond do
      input == "" ->
        {:ok, ""}

      embed_url?(input) ->
        {:ok, input |> embed_url_to_nocookie_embed_url()}

      video_id = youtube_video_id(input) ->
        {:ok, "https://www.youtube-nocookie.com/embed/#{video_id}"}

      true ->
        case extract_iframe_src(input) do
          nil ->
            {:error, invalid_input_message()}

          url when is_binary(url) ->
            if embed_url?(url) do
              {:ok, url |> embed_url_to_nocookie_embed_url()}
            else
              {:error, invalid_input_message()}
            end
        end
    end
  end

  def normalize_embed_input(_input) do
    {:error, invalid_input_message()}
  end

  def embed_url?(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: "https", host: host, path: path}
      when host in [
             "youtube.com",
             "www.youtube.com",
             "youtube-nocookie.com",
             "www.youtube-nocookie.com"
           ] ->
        String.starts_with?(path || "", "/embed/")

      _ ->
        false
    end
  end

  def embed_url?(_), do: false

  defp embed_url_to_nocookie_embed_url(url) do
    url
    |> URI.parse()
    |> then(fn uri -> %{uri | host: "www.youtube-nocookie.com"} end)
    |> URI.to_string()
  end

  defp youtube_video_id(input) do
    case URI.parse(input) do
      %URI{scheme: "https", host: host, path: path, query: query}
      when host in [
             "youtube.com",
             "www.youtube.com",
             "m.youtube.com",
             "youtube-nocookie.com",
             "www.youtube-nocookie.com"
           ] ->
        youtube_video_id_from_query(query) || youtube_video_id_from_path(path, ["shorts"])

      %URI{scheme: "https", host: host, path: path}
      when host in ["youtu.be", "www.youtu.be"] ->
        youtube_video_id_from_path(path, [])

      _uri ->
        valid_video_id(input)
    end
  end

  defp youtube_video_id_from_query(query) when is_binary(query) do
    case Regex.run(~r/(?:^|&)v=([A-Za-z0-9_-]{11})(?:&|$)/, query) do
      [_, video_id] -> video_id
      _no_match -> nil
    end
  end

  defp youtube_video_id_from_query(_query), do: nil

  defp youtube_video_id_from_path(path, prefixes) do
    case String.split(path || "", "/", trim: true) do
      [video_id] -> valid_video_id(video_id)
      [prefix, video_id] -> if prefix in prefixes, do: valid_video_id(video_id)
      _parts -> nil
    end
  end

  defp valid_video_id(video_id) when is_binary(video_id) do
    if Regex.match?(~r/^[A-Za-z0-9_-]{11}$/, video_id), do: video_id
  end

  defp invalid_input_message do
    "YouTube blocks only accept YouTube URLs, embed URLs, or embed iframe code"
  end

  defp extract_iframe_src(input) do
    case Regex.run(~r/src=(["'])(.*?)\1/, input) do
      [_, _, url] ->
        url |> String.replace("&amp;", "&") |> String.trim()

      _ ->
        nil
    end
  end

  defp get_url(%{"url" => url}), do: url
  defp get_url(_), do: nil
end
