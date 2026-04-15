defmodule Qblog.Blocks.Types.SoundCloud do
  alias Qblog.Blocks.Types.Embed

  def label, do: "SoundCloud"
  def type, do: :soundcloud

  defdelegate block_to_form_params(block), to: Embed
  defdelegate block_to_form_params(block, params), to: Embed
  defdelegate update_block(block, params, opts), to: Embed

  def validate_data(data) do
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
          {:error, field: :data, message: "soundcloud blocks must store a SoundCloud embed URL"}
        end

      _ ->
        {:error, field: :data, message: "soundcloud blocks must store a SoundCloud embed URL"}
    end
  end

  def normalize_embed_input(nil), do: {:ok, ""}

  def normalize_embed_input(input) when is_binary(input) do
    input = input |> String.trim()

    cond do
      input == "" ->
        {:ok, ""}

      embed_url?(input) ->
        {:ok, input}

      true ->
        case extract_iframe_src(input) do
          nil ->
            {:error, "SoundCloud blocks only accept SoundCloud embed URLs or embed iframe code"}

          url when is_binary(url) ->
            if embed_url?(url) do
              {:ok, url}
            else
              {:error, "SoundCloud blocks only accept SoundCloud embed URLs or embed iframe code"}
            end
        end
    end
  end

  def normalize_embed_input(_input) do
    {:error, "SoundCloud blocks only accept SoundCloud embed URLs or embed iframe code"}
  end

  def embed_url?(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: "https", host: "w.soundcloud.com", path: path} ->
        String.starts_with?(path || "", "/player")

      _ ->
        false
    end
  end

  def embed_url?(_), do: false

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
