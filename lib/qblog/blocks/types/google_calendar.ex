defmodule Qblog.Blocks.Types.GoogleCalendar do
  def label, do: "Google Calendar"
  def type, do: :google_calendar

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
          {:error,
           field: :data, message: "google calendar blocks must store a Google Calendar embed URL"}
        end

      _ ->
        {:error,
         field: :data, message: "google calendar blocks must store a Google Calendar embed URL"}
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
            {:error,
             "Google Calendar blocks only accept Google Calendar embed URLs or embed iframe code"}

          url when is_binary(url) ->
            if embed_url?(url) do
              {:ok, url}
            else
              {:error,
               "Google Calendar blocks only accept Google Calendar embed URLs or embed iframe code"}
            end
        end
    end
  end

  def normalize_embed_input(_input) do
    {:error, "Google Calendar blocks only accept Google Calendar embed URLs or embed iframe code"}
  end

  def embed_url?(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: "https", host: host, path: path}
      when host in ["calendar.google.com", "www.google.com"] ->
        String.starts_with?(path || "", "/calendar/embed")

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
