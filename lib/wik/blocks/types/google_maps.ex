defmodule Wik.Blocks.Types.GoogleMaps do
  @behaviour Wik.Blocks.Types.Behaviour

  alias Wik.Blocks.Types.Embed

  def label, do: "Google Maps"
  def type, do: :google_maps
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
            {:error, field: :data, message: "google maps blocks must store a Google embed URL"}
          end

        _ ->
          {:error, field: :data, message: "google maps blocks must store a Google embed URL"}
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
        {:ok, input}

      true ->
        case extract_iframe_src(input) do
          nil ->
            {:error, "Google Maps blocks only accept Google embed URLs or embed iframe code"}

          url when is_binary(url) ->
            if embed_url?(url) do
              {:ok, url}
            else
              {:error, "Google Maps blocks only accept Google embed URLs or embed iframe code"}
            end
        end
    end
  end

  def normalize_embed_input(_input) do
    {:error, "Google Maps blocks only accept Google embed URLs or embed iframe code"}
  end

  def embed_url?(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: "https", host: host, path: path}
      when host in ["google.com", "www.google.com"] ->
        String.starts_with?(path || "", "/maps/embed")

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
