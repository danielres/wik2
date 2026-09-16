defmodule WikWeb.LibraryLive.ExternalMedia.YouTube do
  @moduledoc false

  require Logger

  alias Wik.Blocks.Types.YouTube

  @playlist_endpoint "https://www.googleapis.com/youtube/v3/playlists"
  @playlist_items_endpoint "https://www.googleapis.com/youtube/v3/playlistItems"
  @playlist_items_limit 20
  @thumbnail_sizes ["maxres", "standard", "high", "medium", "default"]
  @video_endpoint "https://www.googleapis.com/youtube/v3/videos"

  def resolve(url, opts) do
    http_get = Keyword.get(opts, :http_get, &Req.get/2)
    api_key = Keyword.get(opts, :youtube_api_key)

    with {:ok, reference} <- media_reference(url),
         :ok <- api_key_available(api_key),
         {endpoint, params} <- request(reference, api_key),
         {:ok, %Req.Response{status: 200, body: body}} <-
           http_get.(endpoint, params: params, receive_timeout: 5_000),
         {:ok, metadata} <- metadata(body, reference) do
      metadata = load_playlist_items(metadata, reference, http_get, api_key)
      {:ok, Map.put(metadata, :provider, :youtube)}
    else
      {:error, :invalid_url} ->
        {:error, :unsupported_provider}

      {:error, reason} ->
        {:error, request_error(reason)}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, api_error(body, api_key)}}
    end
  end

  defp api_key_available(api_key) when is_binary(api_key) and api_key != "", do: :ok
  defp api_key_available(_api_key), do: {:error, :missing_api_key}

  defp request_error(%Req.TransportError{reason: reason}), do: {:transport_error, reason}
  defp request_error(reason) when is_atom(reason), do: reason
  defp request_error(error) when is_exception(error), do: {:request_error, error.__struct__}
  defp request_error(_error), do: :request_error

  defp api_error(%{"error" => error}, api_key) when is_map(error) do
    %{
      code: error["code"],
      message: sanitize_message(error["message"], api_key),
      status: error["status"]
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp api_error(_body, _api_key), do: :unrecognized_response

  defp sanitize_message(message, api_key) when is_binary(message) and is_binary(api_key) do
    message
    |> String.replace(api_key, "[REDACTED]")
    |> String.slice(0, 500)
  end

  defp sanitize_message(message, _api_key) when is_binary(message),
    do: String.slice(message, 0, 500)

  defp sanitize_message(_message, _api_key), do: nil

  defp media_reference(url) do
    with {:ok, embed_url} <- YouTube.normalize_embed_input(url),
         %URI{} = uri <- URI.parse(embed_url) do
      reference(uri)
    else
      _error -> {:error, :invalid_url}
    end
  end

  defp reference(%URI{path: "/embed", query: query}) do
    with true <- Regex.match?(~r/(?:^|&)listType=playlist(?:&|$)/, query || ""),
         [_, playlist_id] <-
           Regex.run(~r/(?:^|&)list=([A-Za-z0-9_-]{2,128})(?:&|$)/, query || "") do
      {:ok, {:playlist, playlist_id}}
    else
      _error -> {:error, :invalid_url}
    end
  end

  defp reference(%URI{path: "/embed/" <> video_id}) do
    if Regex.match?(~r/^[A-Za-z0-9_-]{11}$/, video_id) do
      {:ok, {:video, video_id}}
    else
      {:error, :invalid_url}
    end
  end

  defp reference(_uri), do: {:error, :invalid_url}

  defp request({:playlist, playlist_id}, api_key) do
    {@playlist_endpoint,
     [
       fields:
         "items(contentDetails(itemCount),snippet(channelTitle,description,thumbnails,title))",
       id: playlist_id,
       key: api_key,
       part: "snippet,contentDetails"
     ]}
  end

  defp request({:video, video_id}, api_key) do
    {@video_endpoint,
     [
       fields:
         "items(contentDetails(duration),snippet(channelTitle,description,thumbnails,title))",
       id: video_id,
       key: api_key,
       part: "snippet,contentDetails"
     ]}
  end

  defp metadata(
         %{
           "items" => [
             %{
               "snippet" => %{"channelTitle" => creator, "title" => title} = snippet
             } = item
             | _items
           ]
         },
         {:video, _video_id}
       ) do
    {:ok,
     %{
       creator: present_string(creator),
       description: present_string(snippet["description"]),
       duration: item |> get_in(["contentDetails", "duration"]) |> optional_duration(),
       thumbnail_url: thumbnail_url(snippet["thumbnails"]),
       title: present_string(title)
     }}
  end

  defp metadata(
         %{
           "items" => [
             %{"snippet" => %{"channelTitle" => creator, "title" => title} = snippet} = item
             | _items
           ]
         },
         {:playlist, _playlist_id}
       ) do
    {:ok,
     %{
       creator: present_string(creator),
       description: present_string(snippet["description"]),
       duration: nil,
       item_count: item |> get_in(["contentDetails", "itemCount"]) |> optional_item_count(),
       kind: :playlist,
       thumbnail_url: thumbnail_url(snippet["thumbnails"]),
       title: present_string(title)
     }}
  end

  defp metadata(_body, _reference), do: {:error, :invalid_response}

  defp load_playlist_items(metadata, {:playlist, playlist_id}, http_get, api_key) do
    result =
      http_get.(@playlist_items_endpoint,
        params: [
          fields: "items(snippet(resourceId(videoId),title))",
          key: api_key,
          maxResults: @playlist_items_limit,
          part: "snippet",
          playlistId: playlist_id
        ],
        receive_timeout: 5_000
      )

    case result do
      {:ok, %Req.Response{status: 200, body: body}} ->
        case playlist_items(body) do
          {:ok, items} -> Map.put(metadata, :playlist_items, items)
          {:error, reason} -> playlist_items_failed(metadata, reason)
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        playlist_items_failed(metadata, {:http_error, status, api_error(body, api_key)})

      {:error, reason} ->
        playlist_items_failed(metadata, request_error(reason))
    end
  end

  defp load_playlist_items(metadata, {:video, _video_id}, _http_get, _api_key), do: metadata

  defp playlist_items(%{"items" => items}) when is_list(items) do
    items =
      Enum.flat_map(items, fn
        %{
          "snippet" => %{
            "resourceId" => %{"videoId" => video_id},
            "title" => title
          }
        } ->
          case {present_string(title), present_string(video_id)} do
            {nil, _video_id} -> []
            {_title, nil} -> []
            {title, video_id} -> [%{title: title, video_id: video_id}]
          end

        _item ->
          []
      end)

    {:ok, items}
  end

  defp playlist_items(_body), do: {:error, :invalid_response}

  defp playlist_items_failed(metadata, reason) do
    Logger.warning("YouTube playlist items could not be loaded: reason=#{inspect(reason)}")
    Map.put(metadata, :playlist_items, [])
  end

  defp thumbnail_url(thumbnails) when is_map(thumbnails) do
    Enum.find_value(@thumbnail_sizes, fn size ->
      case thumbnails[size] do
        %{"url" => url} -> present_string(url)
        _thumbnail -> nil
      end
    end)
  end

  defp thumbnail_url(_thumbnails), do: nil

  defp format_duration(duration) when is_binary(duration) do
    case Regex.named_captures(
           ~r/^P(?:(?<days>\d+)D)?T(?:(?<hours>\d+)H)?(?:(?<minutes>\d+)M)?(?:(?<seconds>\d+)S)?$/,
           duration
         ) do
      nil ->
        {:error, :invalid_duration}

      captures ->
        seconds =
          parse_part(captures["days"]) * 86_400 +
            parse_part(captures["hours"]) * 3_600 +
            parse_part(captures["minutes"]) * 60 + parse_part(captures["seconds"])

        {:ok, seconds_to_clock(seconds)}
    end
  end

  defp format_duration(_duration), do: {:error, :invalid_duration}

  defp optional_duration(duration) do
    case format_duration(duration) do
      {:ok, duration} -> duration
      {:error, _reason} -> nil
    end
  end

  defp optional_item_count(item_count) when is_integer(item_count) and item_count >= 0,
    do: item_count

  defp optional_item_count(_item_count), do: nil

  defp parse_part(""), do: 0
  defp parse_part(value), do: String.to_integer(value)

  defp seconds_to_clock(seconds) do
    hours = div(seconds, 3_600)
    minutes = seconds |> rem(3_600) |> div(60)
    seconds = rem(seconds, 60)

    if hours > 0 do
      "#{hours}:#{pad(minutes)}:#{pad(seconds)}"
    else
      "#{minutes}:#{pad(seconds)}"
    end
  end

  defp pad(value), do: value |> Integer.to_string() |> String.pad_leading(2, "0")

  defp present_string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      value -> value
    end
  end

  defp present_string(_value), do: nil
end
