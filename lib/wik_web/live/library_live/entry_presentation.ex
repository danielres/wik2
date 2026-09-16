defmodule WikWeb.LibraryPrototypeLive.EntryPresentation do
  alias Wik.Blocks.Types.SoundCloud
  alias Wik.Blocks.Types.YouTube
  alias WikWeb.LibraryPrototypeLive.Schema

  def title(type, entry) do
    title_field = Enum.find(type.fields, &(&1.type == :title))
    Schema.field_value(entry, title_field) || "Untitled"
  end

  def media_embed(value) when is_binary(value) do
    with {:error, _message} <- YouTube.normalize_embed_input(value),
         {:error, _message} <- soundcloud_embed(value) do
      nil
    else
      {:ok, ""} -> nil
      {:ok, embed_url} -> media_provider(embed_url)
    end
  end

  def media_embed(_value), do: nil

  def playlist_label(type, entry) when is_map(type) and is_map(entry) do
    media_value = entry_media_value(type, entry)

    case media_embed(media_value) do
      %{kind: :playlist, provider: :youtube} ->
        playlist_count_label(metadata(entry), media_value)

      _preview ->
        nil
    end
  end

  def playlist_label(_type, _entry), do: nil

  def map_embed_url(type, entry) do
    type.fields
    |> Enum.find_value(fn field ->
      value = Schema.field_value(entry, field)

      if field.type == :location and not Schema.blank_value?(value), do: value
    end)
    |> google_maps_embed_url()
  end

  def preview(type, entry) do
    external_media_metadata = metadata(entry)

    Enum.find_value(type.fields, fn field ->
      value = Schema.field_value(entry, field)

      if not Schema.blank_value?(value) do
        card_field_preview(field.type, value, external_media_metadata)
      end
    end)
  end

  defp card_field_preview(
         :media,
         value,
         %{
           kind: :playlist,
           provider: :youtube,
           source_url: source_url,
           thumbnail_url: thumbnail_url
         }
       )
       when source_url == value and is_binary(thumbnail_url) and thumbnail_url != "" do
    case field_preview(:media, value) do
      %{kind: :playlist, provider: :youtube} = preview ->
        %{preview | thumbnail_url: thumbnail_url}

      preview ->
        preview
    end
  end

  defp card_field_preview(type, value, _external_media_metadata),
    do: field_preview(type, value)

  defp field_preview(:location, value) do
    %{embed_url: google_maps_embed_url(value), provider: :google_maps, thumbnail_url: nil}
  end

  defp field_preview(:media, value) do
    media_embed(value) || %{embed_url: nil, provider: :link, thumbnail_url: nil}
  end

  defp field_preview(_type, _value), do: nil

  defp google_maps_embed_url(location) when is_binary(location) do
    api_key =
      :wik
      |> Application.get_env(WikWeb.LibraryPrototypeLive.Components, [])
      |> Keyword.get(:google_maps_api_key)

    if is_binary(api_key) and api_key != "" do
      query = URI.encode_query(%{"key" => api_key, "q" => to_string(location)})
      "https://www.google.com/maps/embed/v1/place?#{query}"
    end
  end

  defp google_maps_embed_url(_location), do: nil

  def media(type, entry) do
    case entry_media_value(type, entry) do
      nil -> nil
      value -> field_preview(:media, value)
    end
  end

  defp entry_media_value(type, entry) do
    Enum.find_value(type.fields, fn field ->
      value = Schema.field_value(entry, field)

      if field.type == :media and not Schema.blank_value?(value), do: value
    end)
  end

  def playlist(type, entry) do
    media_value = entry_media_value(type, entry)

    case {media_embed(media_value), metadata(entry)} do
      {
        %{kind: :playlist, provider: :youtube},
        %{
          item_count: item_count,
          kind: :playlist,
          playlist_items: items,
          provider: :youtube,
          source_url: ^media_value
        }
      }
      when is_list(items) ->
        remaining_count =
          if is_integer(item_count), do: max(item_count - length(items), 0), else: 0

        %{items: items, remaining_count: remaining_count, source_url: media_value}

      _media_and_metadata ->
        %{items: [], remaining_count: 0, source_url: nil}
    end
  end

  def youtube_video_embed_url(video_id) do
    "https://www.youtube-nocookie.com/embed/#{URI.encode_www_form(video_id)}?autoplay=1"
  end

  defp playlist_count_label(
         %{item_count: item_count, kind: :playlist, provider: :youtube, source_url: source_url},
         media_value
       )
       when is_integer(item_count) and item_count >= 0 and source_url == media_value do
    video_label = if item_count == 1, do: "video", else: "videos"
    "#{item_count} #{video_label}"
  end

  defp playlist_count_label(_metadata, _media_value), do: "Playlist"

  defp metadata(entry) do
    case Map.get(entry, :external_media_metadata) do
      metadata when is_map(metadata) ->
        %{
          item_count: metadata_value(metadata, :item_count),
          kind: metadata_value(metadata, :kind) |> metadata_atom([:playlist, :video]),
          playlist_items:
            metadata
            |> metadata_value(:playlist_items)
            |> normalize_playlist_items(),
          provider: metadata_value(metadata, :provider) |> metadata_atom([:youtube, :soundcloud]),
          source_url: metadata_value(metadata, :source_url),
          thumbnail_url: metadata_value(metadata, :thumbnail_url)
        }

      _other ->
        nil
    end
  end

  defp metadata_value(metadata, key),
    do: Map.get(metadata, key) || Map.get(metadata, Atom.to_string(key))

  defp metadata_atom(value, allowed) when is_atom(value) do
    if value in allowed, do: value
  end

  defp metadata_atom(value, allowed) when is_binary(value) do
    Enum.find(allowed, &(Atom.to_string(&1) == value))
  end

  defp metadata_atom(_value, _allowed), do: nil

  defp normalize_playlist_items(items) when is_list(items) do
    Enum.map(items, fn item ->
      %{
        title: metadata_value(item, :title),
        video_id: metadata_value(item, :video_id)
      }
    end)
  end

  defp normalize_playlist_items(_items), do: []

  defp soundcloud_embed(value) do
    case URI.parse(value) do
      %URI{host: host, scheme: "https"}
      when host in ["soundcloud.com", "www.soundcloud.com"] ->
        query =
          URI.encode_query(%{
            "url" => value,
            "color" => "",
            "auto_play" => "false",
            "hide_related" => "true",
            "show_comments" => "false",
            "show_user" => "false",
            "show_reposts" => "false",
            "show_teaser" => "false",
            "visual" => "true"
          })

        SoundCloud.normalize_embed_input("https://w.soundcloud.com/player/?#{query}")

      _uri ->
        SoundCloud.normalize_embed_input(value)
    end
  end

  defp media_provider("https://www.youtube-nocookie.com/embed?" <> _query = embed_url) do
    %{embed_url: embed_url, kind: :playlist, provider: :youtube, thumbnail_url: nil}
  end

  defp media_provider("https://www.youtube-nocookie.com/embed/" <> value = embed_url) do
    video_id = value |> String.split("?", parts: 2) |> hd()

    %{
      embed_url: embed_url,
      provider: :youtube,
      thumbnail_url: "https://i.ytimg.com/vi/#{video_id}/hqdefault.jpg"
    }
  end

  defp media_provider("https://w.soundcloud.com/player" <> _rest = embed_url) do
    %{embed_url: embed_url, provider: :soundcloud, thumbnail_url: nil}
  end

  defp media_provider(_embed_url), do: nil
end
