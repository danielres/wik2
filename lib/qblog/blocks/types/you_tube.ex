defmodule Qblog.Blocks.Types.YouTube do
  def label, do: "YouTube"
  def type, do: :youtube

  def block_to_form_params(block), do: block |> block_to_form_params(%{})

  def block_to_form_params(block, params) do
    %{"url" => params["url"] || block.data |> get_url() || ""}
  end

  def update_block(block, params, opts) do
    _scope = Keyword.fetch!(opts, :scope)

    with {:ok, url} <- params["url"] |> normalize_embed_input() do
      block
      |> Ash.update(%{data: %{"url" => url}}, opts |> Keyword.put(:action, :update))
    end
  end

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
          {:error, field: :data, message: "youtube blocks must store a YouTube embed URL"}
        end

      _ ->
        {:error, field: :data, message: "youtube blocks must store a YouTube embed URL"}
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

      true ->
        case extract_iframe_src(input) do
          nil ->
            {:error, "YouTube blocks only accept YouTube embed URLs or embed iframe code"}

          url when is_binary(url) ->
            if embed_url?(url) do
              {:ok, url |> embed_url_to_nocookie_embed_url()}
            else
              {:error, "YouTube blocks only accept YouTube embed URLs or embed iframe code"}
            end
        end
    end
  end

  def normalize_embed_input(_input) do
    {:error, "YouTube blocks only accept YouTube embed URLs or embed iframe code"}
  end

  def embed_url?(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: "https", host: host, path: path}
      when host in ["youtube.com", "www.youtube.com", "youtube-nocookie.com", "www.youtube-nocookie.com"] ->
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
