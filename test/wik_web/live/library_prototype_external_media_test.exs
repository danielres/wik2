defmodule WikWeb.LibraryPrototypeExternalMediaTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias WikWeb.LibraryPrototypeLive.EntryPresentation
  alias WikWeb.LibraryPrototypeLive.ExternalMedia
  alias WikWeb.LibraryPrototypeLive.Schema
  alias WikWeb.LibraryPrototypeLive.State

  test "resolves YouTube metadata through the fixed Data API endpoint" do
    http_get = fn url, opts ->
      assert url == "https://www.googleapis.com/youtube/v3/videos"
      assert opts[:params][:id] == "BvlGs25tCxI"
      assert opts[:params][:key] == "api-key"

      assert opts[:params][:fields] ==
               "items(contentDetails(duration),snippet(channelTitle,description,thumbnails,title))"

      {:ok,
       %Req.Response{
         status: 200,
         body: %{
           "items" => [
             %{
               "contentDetails" => %{"duration" => "P1DT2H3M4S"},
               "snippet" => %{
                 "channelTitle" => "Channel",
                 "description" => "Video description",
                 "thumbnails" => %{
                   "high" => %{"url" => "https://example.test/high.jpg"},
                   "maxres" => %{"url" => "https://example.test/maxres.jpg"}
                 },
                 "title" => "Video title"
               }
             }
           ]
         }
       }}
    end

    assert {:ok,
            %{
              creator: "Channel",
              description: "Video description",
              duration: "26:03:04",
              provider: :youtube,
              thumbnail_url: "https://example.test/maxres.jpg",
              title: "Video title"
            }} =
             ExternalMedia.resolve("https://youtu.be/BvlGs25tCxI",
               http_get: http_get,
               youtube_api_key: "api-key"
             )
  end

  test "resolves YouTube playlist metadata through the playlists endpoint" do
    playlist_id = "PL-ZQIvQFPv4LYaNhtbleNaepGSGsuzQyp"

    http_get = fn
      "https://www.googleapis.com/youtube/v3/playlists", opts ->
        assert opts[:params][:id] == playlist_id
        assert opts[:params][:key] == "api-key"
        assert opts[:params][:part] == "snippet,contentDetails"

        assert opts[:params][:fields] ==
                 "items(contentDetails(itemCount),snippet(channelTitle,description,thumbnails,title))"

        {:ok,
         %Req.Response{
           status: 200,
           body: %{
             "items" => [
               %{
                 "contentDetails" => %{"itemCount" => 24},
                 "snippet" => %{
                   "channelTitle" => "Playlist channel",
                   "description" => "Playlist description",
                   "thumbnails" => %{
                     "high" => %{"url" => "https://example.test/playlist.jpg"}
                   },
                   "title" => "Playlist title"
                 }
               }
             ]
           }
         }}

      "https://www.googleapis.com/youtube/v3/playlistItems", opts ->
        assert opts[:params][:fields] == "items(snippet(resourceId(videoId),title))"
        assert opts[:params][:key] == "api-key"
        assert opts[:params][:maxResults] == 20
        assert opts[:params][:part] == "snippet"
        assert opts[:params][:playlistId] == playlist_id

        {:ok,
         %Req.Response{
           status: 200,
           body: %{
             "items" => [
               %{
                 "snippet" => %{
                   "resourceId" => %{"videoId" => "video-one"},
                   "title" => "First video"
                 }
               },
               %{
                 "snippet" => %{
                   "resourceId" => %{"videoId" => "video-two"},
                   "title" => "Second video"
                 }
               }
             ]
           }
         }}
    end

    assert {:ok,
            %{
              creator: "Playlist channel",
              description: "Playlist description",
              duration: nil,
              item_count: 24,
              kind: :playlist,
              playlist_items: [
                %{title: "First video", video_id: "video-one"},
                %{title: "Second video", video_id: "video-two"}
              ],
              provider: :youtube,
              thumbnail_url: "https://example.test/playlist.jpg",
              title: "Playlist title"
            }} =
             ExternalMedia.resolve(
               "https://youtube.com/playlist?list=#{playlist_id}&si=example",
               http_get: http_get,
               youtube_api_key: "api-key"
             )
  end

  test "keeps playlist metadata when its item list cannot be loaded" do
    http_get = fn
      "https://www.googleapis.com/youtube/v3/playlists", _opts ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{
             "items" => [
               %{
                 "contentDetails" => %{"itemCount" => 24},
                 "snippet" => %{
                   "channelTitle" => "Playlist channel",
                   "description" => "Playlist description",
                   "title" => "Playlist title"
                 }
               }
             ]
           }
         }}

      "https://www.googleapis.com/youtube/v3/playlistItems", _opts ->
        {:ok, %Req.Response{status: 503, body: %{}}}
    end

    log =
      capture_log(fn ->
        assert {:ok,
                %{
                  description: "Playlist description",
                  playlist_items: [],
                  title: "Playlist title"
                }} =
                 ExternalMedia.resolve(
                   "https://youtube.com/playlist?list=playlist-one",
                   http_get: http_get,
                   youtube_api_key: "api-key"
                 )
      end)

    assert log =~ "YouTube playlist items could not be loaded"
    assert log =~ "http_error"
  end

  test "renders a YouTube playlist as an iframe instead of a video thumbnail" do
    assert %{
             embed_url:
               "https://www.youtube-nocookie.com/embed?listType=playlist&list=PL-ZQIvQFPv4LYaNhtbleNaepGSGsuzQyp",
             kind: :playlist,
             provider: :youtube,
             thumbnail_url: nil
           } =
             EntryPresentation.media_embed(
               "https://youtube.com/playlist?list=PL-ZQIvQFPv4LYaNhtbleNaepGSGsuzQyp&si=example"
             )
  end

  test "labels playlists with a matching video count and falls back without one" do
    media = "https://youtube.com/playlist?list=PL-ZQIvQFPv4LYaNhtbleNaepGSGsuzQyp"
    type = %{fields: [%{key: "media", type: :media}]}

    entry = %{
      external_media_metadata: %{
        item_count: 1,
        kind: :playlist,
        provider: :youtube,
        source_url: media
      },
      values: %{"media" => media}
    }

    assert EntryPresentation.playlist_label(type, entry) == "1 video"

    stale_entry = put_in(entry.external_media_metadata.source_url, "https://example.test/old")
    assert EntryPresentation.playlist_label(type, stale_entry) == "Playlist"
  end

  test "resolves SoundCloud metadata without fetching the pasted URL" do
    pasted_url = "https://soundcloud.com/artist/track"

    http_get = fn url, opts ->
      assert url == "https://soundcloud.com/oembed"
      assert opts[:params][:url] == pasted_url

      {:ok,
       %Req.Response{
         status: 200,
         body: %{
           "author_name" => "Artist",
           "description" => "Track description",
           "thumbnail_url" => "https://example.test/artwork.jpg",
           "title" => "Track"
         }
       }}
    end

    assert {:ok,
            %{
              creator: "Artist",
              description: "Track description",
              duration: nil,
              provider: :soundcloud,
              thumbnail_url: "https://example.test/artwork.jpg",
              title: "Track"
            }} = ExternalMedia.resolve(pasted_url, http_get: http_get)
  end

  test "rejects unsupported and lookalike hosts without an HTTP request" do
    http_get = fn _url, _opts -> flunk("unsupported URLs must not be fetched") end

    assert {:error, :unsupported_provider} =
             ExternalMedia.resolve("https://youtube.com.example.test/watch?v=BvlGs25tCxI",
               http_get: http_get,
               youtube_api_key: "api-key"
             )

    assert {:error, :unsupported_provider} =
             ExternalMedia.resolve("https://example.test/media", http_get: http_get)
  end

  test "fails safely when the YouTube API key is unavailable" do
    http_get = fn _url, _opts -> flunk("a request must not be made without an API key") end

    log =
      capture_log(fn ->
        assert {:error, :unavailable} =
                 ExternalMedia.resolve("https://youtu.be/BvlGs25tCxI", http_get: http_get)
      end)

    assert log =~
             "External media details could not be loaded: provider=youtube reason=:missing_api_key"
  end

  test "logs a sanitized YouTube API response without exposing the key" do
    http_get = fn _url, _opts ->
      {:ok,
       %Req.Response{
         status: 403,
         body: %{
           "error" => %{
             "code" => 403,
             "message" => "API key secret-api-key is not authorized",
             "status" => "PERMISSION_DENIED"
           }
         }
       }}
    end

    log =
      capture_log(fn ->
        assert {:error, :unavailable} =
                 ExternalMedia.resolve("https://youtu.be/BvlGs25tCxI",
                   http_get: http_get,
                   youtube_api_key: "secret-api-key"
                 )
      end)

    assert log =~ "provider=youtube"
    assert log =~ "http_error"
    assert log =~ "PERMISSION_DENIED"
    assert log =~ "[REDACTED]"
    refute log =~ "secret-api-key"
  end

  test "keeps YouTube metadata when duration is unavailable" do
    http_get = fn _url, _opts ->
      {:ok,
       %Req.Response{
         status: 200,
         body: %{
           "items" => [
             %{
               "snippet" => %{"channelTitle" => "Channel", "title" => "Live video"}
             }
           ]
         }
       }}
    end

    assert {:ok, %{duration: nil, title: "Live video"}} =
             ExternalMedia.resolve("https://youtu.be/BvlGs25tCxI",
               http_get: http_get,
               youtube_api_key: "api-key"
             )
  end

  test "defines one media-first external media template" do
    templates = Schema.built_in_templates()
    template = Schema.find_template(templates, "external-media")

    assert Enum.map(template.fields, &{&1.key, &1.type, &1.required?}) == [
             {"media", :media, true},
             {"title", :title, true},
             {"creator", :text, false},
             {"duration", :text, false},
             {"notes", :rich_text, false}
           ]

    refute Schema.find_template(templates, "video")
    refute Schema.find_template(templates, "music")
  end

  test "imports a schema whose required title field is not first" do
    blueprint =
      Jason.encode!(%{
        "fields" => [
          %{"key" => "media", "label" => "Media", "required" => true, "type" => "media"},
          %{"key" => "title", "label" => "Title", "required" => true, "type" => "title"}
        ],
        "format" => "wik-library-type",
        "type" => %{"description" => "External media", "name" => "External media"},
        "version" => 1
      })

    assert {:ok, %{fields: [%{type: :media}, %{required?: true, type: :title}]}} =
             Schema.import(blueprint)
  end

  test "moves the title field without changing its invariants" do
    state = State.new()
    type = State.find_type(state, "external-media")
    title = Enum.find(type.fields, &(&1.type == :title))

    assert {:ok, _state, moved_type} = State.move_field(state, type.id, title.id, :up)
    assert Enum.map(moved_type.fields, & &1.type) |> Enum.take(2) == [:title, :media]
    assert Enum.find(moved_type.fields, &(&1.type == :title)).required?
  end
end
