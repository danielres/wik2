defmodule WikWeb.LibraryPrototypeLiveTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Accounts.Membership
  alias Wik.Scope
  alias Wik.Tags
  alias WikWeb.LibraryPrototypeLive.Components.EntryCard
  alias WikWeb.LibraryPrototypeLive.ExternalMedia
  alias WikWeb.LibraryPrototypeLive.Schema
  alias WikWeb.LibraryPrototypeLive.State

  setup %{conn: conn} do
    previous_google_maps_config =
      Application.get_env(:wik, WikWeb.LibraryPrototypeLive.Components, [])

    previous_external_media_config = Application.get_env(:wik, ExternalMedia, [])

    Application.put_env(:wik, WikWeb.LibraryPrototypeLive.Components,
      google_maps_api_key: "test-api-key"
    )

    Application.put_env(:wik, ExternalMedia,
      http_get: &external_media_get/2,
      youtube_api_key: "test-youtube-api-key"
    )

    on_exit(fn ->
      Application.put_env(
        :wik,
        WikWeb.LibraryPrototypeLive.Components,
        previous_google_maps_config
      )

      Application.put_env(:wik, ExternalMedia, previous_external_media_config)
    end)

    owner = generate(user())
    space = generate(space(author: owner))
    membership = add_membership(space, owner, :owner)

    %{
      conn: log_in(conn, owner),
      membership: membership,
      owner: owner,
      space: space
    }
  end

  test "shows every entry in one feed with compact topic and type filters", %{
    conn: conn,
    owner: owner,
    space: space
  } do
    create_topic!(owner, space, "berlin", "Berlin")
    create_topic!(owner, space, "unassigned", "Unassigned")

    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries")

    assert has_element?(view, testid("library-page"))
    assert has_element?(view, testid("library-toolbar"))

    assert has_element?(
             view,
             testid("library-settings-open") <>
               ~s([popovertarget="library-settings-popover"])
           )

    assert has_element?(
             view,
             ~s(#library-settings-popover[popover][style="position-anchor:--library-settings-anchor"])
           )

    assert has_element?(
             view,
             testid("topic-filter") <>
               ~s([popovertarget="topic-filter-popover"][style="anchor-name:--topic-filter-anchor"])
           )

    assert has_element?(
             view,
             ~s(#topic-filter-popover[popover][style="position-anchor:--topic-filter-anchor"])
           )

    assert has_element?(view, testid("type-filters"))
    refute has_element?(view, "#type-filter-popover[popover]")
    assert has_element?(view, testid("topic-filter-berlin") <> " .hero-check-micro")
    refute has_element?(view, testid("topic-filter-unassigned"))
    assert has_element?(view, testid("type-filter-place") <> " .hero-check-micro")
    assert has_element?(view, testid("type-filter-external-media") <> " .hero-check-micro")
    assert has_element?(view, testid("library-entry-entry-place"))
    assert has_element?(view, testid("library-entry-entry-contact"))
    assert has_element?(view, testid("library-entry-entry-video"))
    assert has_element?(view, testid("library-entry-entry-music"))
    assert has_element?(view, testid("entry-open-entry-video"))

    assert has_element?(
             view,
             testid("library-entry-entry-video") <> ~s( img[src*="i.ytimg.com"])
           )

    assert has_element?(
             view,
             testid("library-entry-entry-music") <> ~s( iframe[src*="w.soundcloud.com"])
           )

    assert has_element?(
             view,
             testid("library-entry-entry-place") <>
               ~s( iframe[src^="https://www.google.com/maps/embed/v1/place?"])
           )

    assert has_element?(
             view,
             testid("library-entry-entry-place") <>
               ~s( dt[title="Location"] .hero-map-pin-micro)
           )

    assert has_element?(
             view,
             testid("library-entry-entry-contact") <>
               ~s( dt[title="Organization"] .hero-home)
           )

    assert has_element?(
             view,
             testid("library-entry-entry-contact") <>
               ~s( dt[title="Role or title"] .hero-academic-cap)
           )

    refute has_element?(view, ~s([data-testid^="collection-"]))

    view |> element(testid("entry-open-entry-music")) |> render_click()
    assert_patch(view, ~p"/#{space.slug}/libraries/entries/entry-music")
    assert has_element?(view, testid("library-entry-detail-entry-music"))
  end

  test "combines OR topic filters with OR type filters across dimensions", %{
    conn: conn,
    owner: owner,
    space: space
  } do
    berlin = create_topic!(owner, space, "berlin", "Berlin")
    software = create_topic!(owner, space, "software", "Software")

    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries")

    view |> element(testid("topic-filter-berlin")) |> render_click()
    assert_patch(view, ~p"/#{space.slug}/libraries?#{%{topics: berlin.slug}}")
    assert has_element?(view, testid("topic-filter-berlin") <> " .hero-check-micro")
    assert has_element?(view, testid("topic-filter-software") <> " .hero-check-micro.opacity-20")
    assert has_element?(view, testid("entry-open-entry-place"))
    refute has_element?(view, testid("entry-open-entry-video"))

    view |> element(testid("topic-filter-software")) |> render_click()

    assert_patch(
      view,
      ~p"/#{space.slug}/libraries?#{%{topics: Enum.join([berlin.slug, software.slug], ",")}}"
    )

    assert has_element?(view, testid("entry-open-entry-place"))
    assert has_element?(view, testid("entry-open-entry-video"))

    view |> element(testid("type-filter-external-media")) |> render_click()

    assert has_element?(view, testid("entry-open-entry-video"))
    refute has_element?(view, testid("entry-open-entry-place"))

    view |> element(testid("active-topic-filters-clear")) |> render_click()

    assert_patch(view, ~p"/#{space.slug}/libraries?#{%{types: "external-media"}}")
    refute has_element?(view, testid("active-topic-filters-clear"))
    assert has_element?(view, testid("topic-filter-berlin") <> " .hero-check-micro")
    assert has_element?(view, testid("topic-filter-software") <> " .hero-check-micro")
    assert has_element?(view, testid("entry-open-entry-video"))
    refute has_element?(view, testid("entry-open-entry-place"))
  end

  test "embeds the location in place entry details", %{conn: conn, space: space} do
    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries/entries/entry-place")

    assert has_element?(
             view,
             testid("entry-location-map") <>
               ~s([src^="https://www.google.com/maps/embed/v1/place?"][src*="q=Spreeacker"])
           )
  end

  test "shows the seeded YouTube playlist result", %{conn: conn, space: space} do
    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries/entries/entry-playlist")

    assert has_element?(view, testid("entry-playlist-indicator"), "8 videos")

    assert has_element?(
             view,
             testid("library-entry-entry-playlist") <>
               ~s( img[src="https://i.ytimg.com/vi/tbRdHktBv58/hqdefault.jpg"])
           )

    assert has_element?(view, testid("entry-playlist-items"))

    assert has_element?(
             view,
             testid("entry-playlist-item-1") <>
               ~s([href="https://www.youtube.com/watch?v=tbRdHktBv58"]),
             "LOCRIAN doesn't have to be S p O o K y"
           )

    assert has_element?(
             view,
             testid("entry-playlist-item-8"),
             "What are the Melodic Minor Modes?"
           )

    refute has_element?(view, testid("entry-playlist-remaining"))
  end

  test "uses the first populated location or media field as the card preview" do
    title_field = %{key: "name", label: "Name", type: :title}
    location_field = %{key: "location", label: "Location", type: :location}
    media_field = %{key: "media", label: "Media", type: :media}

    entry = %{
      id: "entry-with-location-and-media",
      values: %{
        "location" => "Spreeacker, Berlin",
        "media" => "https://www.youtube.com/watch?v=BvlGs25tCxI",
        "name" => "Mixed preview"
      }
    }

    render_preview = fn fields ->
      render_component(&EntryCard.render/1, %{
        entry: entry,
        manageable?: false,
        owned?: false,
        topic_summaries: [],
        type: %{fields: fields, name: "Mixed"}
      })
      |> LazyHTML.from_fragment()
    end

    location_first = render_preview.([title_field, location_field, media_field])

    assert location_first
           |> LazyHTML.query(~s(iframe[src^="https://www.google.com/maps/embed/v1/place?"]))
           |> Enum.any?()

    refute location_first |> LazyHTML.query(~s(img[src*="i.ytimg.com"])) |> Enum.any?()

    media_first = render_preview.([title_field, media_field, location_field])

    assert media_first |> LazyHTML.query(~s(img[src*="i.ytimg.com"])) |> Enum.any?()

    refute media_first
           |> LazyHTML.query(~s(iframe[src^="https://www.google.com/maps/embed/v1/place?"]))
           |> Enum.any?()
  end

  test "adds an entry by choosing its type first", %{conn: conn, space: space} do
    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries")

    view |> element(testid("entry-create-open")) |> render_click()
    assert_patch(view, ~p"/#{space.slug}/libraries/entries/new")
    assert has_element?(view, testid("entry-type-picker"))

    view |> element(testid("entry-type-select-place")) |> render_click()
    assert has_element?(view, testid("entry-form"))

    view
    |> form(testid("entry-form"),
      entry: %{
        location: "Kreuzberg, Berlin",
        name: "My dance studio",
        notes: "Weekly community practice",
        phone: "",
        website: ""
      }
    )
    |> render_submit()

    assert has_element?(view, ~s([data-testid^="library-entry-detail-entry-"]))

    view |> element(testid("library-modal-close")) |> render_click()
    assert_patch(view, ~p"/#{space.slug}/libraries")

    assert has_element?(
             view,
             ~s(#library-entries [data-testid^="library-entry-entry-"] .badge-outline)
           )
  end

  test "prefills an external media entry from a YouTube URL", %{conn: conn, space: space} do
    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries")

    view |> element(testid("entry-create-open")) |> render_click()
    view |> element(testid("entry-type-select-external-media")) |> render_click()

    view
    |> form(testid("entry-form"),
      entry: %{
        creator: "",
        duration: "",
        media: "https://www.youtube.com/watch?v=BvlGs25tCxI",
        notes: "",
        title: ""
      }
    )
    |> render_change()

    render_async(view)

    assert has_element?(view, testid("entry-field-title") <> ~s([value="Fetched title"]))
    assert has_element?(view, testid("entry-field-creator") <> ~s([value="Fetched channel"]))
    assert has_element?(view, testid("entry-field-duration") <> ~s([value="1:02:03"]))
    assert has_element?(view, "#entry-notes-textarea", "Fetched video description")
    refute has_element?(view, testid("entry-media-status"))
  end

  test "prefills an external media entry from a YouTube playlist URL", %{
    conn: conn,
    space: space
  } do
    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries")

    view |> element(testid("entry-create-open")) |> render_click()
    view |> element(testid("entry-type-select-external-media")) |> render_click()

    view
    |> form(testid("entry-form"),
      entry: %{
        creator: "",
        duration: "",
        media: "https://youtube.com/playlist?list=PL-ZQIvQFPv4LYaNhtbleNaepGSGsuzQyp&si=example",
        notes: "",
        title: ""
      }
    )
    |> render_change()

    render_async(view)

    assert has_element?(view, testid("entry-field-title") <> ~s([value="Fetched playlist"]))

    assert has_element?(
             view,
             testid("entry-field-creator") <> ~s([value="Fetched playlist channel"])
           )

    assert has_element?(view, testid("entry-field-duration") <> ~s([value=""]))
    assert has_element?(view, "#entry-notes-textarea", "Fetched playlist description")
    refute has_element?(view, testid("entry-media-status"))

    view |> form(testid("entry-form")) |> render_submit()

    assert has_element?(
             view,
             testid("entry-playlist-indicator"),
             "24 videos"
           )

    assert has_element?(
             view,
             ~s([data-testid^="library-entry-detail-entry-"] iframe[src*="listType=playlist"])
           )

    assert has_element?(view, testid("entry-playlist-items"))

    assert has_element?(
             view,
             testid("entry-playlist-item-1") <>
               ~s([href="https://www.youtube.com/watch?v=playlist-video-one"]),
             "First playlist video"
           )

    assert has_element?(
             view,
             testid("entry-playlist-item-2") <>
               ~s([href="https://www.youtube.com/watch?v=playlist-video-two"]),
             "Second playlist video"
           )

    assert has_element?(view, testid("entry-playlist-remaining"), "…and 22 more")

    view |> element(testid("library-modal-close")) |> render_click()

    assert has_element?(
             view,
             ~s([data-testid^="entry-playlist-indicator-entry-"]),
             "24 videos"
           )

    assert has_element?(
             view,
             ~s([data-testid^="entry-preview-entry-"] img[src="https://example.test/playlist.jpg"])
           )
  end

  test "prefills Notes from a SoundCloud description", %{conn: conn, space: space} do
    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries")

    view |> element(testid("entry-create-open")) |> render_click()
    view |> element(testid("entry-type-select-external-media")) |> render_click()

    view
    |> form(testid("entry-form"),
      entry: %{
        creator: "",
        duration: "",
        media: "https://soundcloud.com/artist/track",
        notes: "",
        title: ""
      }
    )
    |> render_change()

    render_async(view)

    assert has_element?(view, "#entry-notes-textarea", "Fetched track description")
  end

  test "keeps manual values when resolving a different media URL", %{conn: conn, space: space} do
    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries")

    view |> element(testid("entry-create-open")) |> render_click()
    view |> element(testid("entry-type-select-external-media")) |> render_click()

    first_entry_params = %{
      creator: "",
      duration: "",
      media: "https://www.youtube.com/watch?v=BvlGs25tCxI",
      notes: "",
      title: ""
    }

    view
    |> form(testid("entry-form"), entry: first_entry_params)
    |> render_change()

    render_async(view)

    manually_edited_params = %{
      creator: "Fetched channel",
      duration: "1:02:03",
      media: "https://www.youtube.com/watch?v=BvlGs25tCxI",
      notes: "Manual notes",
      title: "Manual title"
    }

    view
    |> form(testid("entry-form"), entry: manually_edited_params)
    |> render_change()

    view
    |> form(testid("entry-form"),
      entry: %{manually_edited_params | media: "https://youtu.be/UuU-Go8GoeY"}
    )
    |> render_change()

    render_async(view)

    assert has_element?(view, testid("entry-field-title") <> ~s([value="Manual title"]))
    assert has_element?(view, testid("entry-field-creator") <> ~s([value="Second channel"]))
    assert has_element?(view, testid("entry-field-duration") <> ~s([value="4:05"]))
    assert has_element?(view, "#entry-notes-textarea", "Manual notes")
  end

  test "members can dismiss an automatic topic and add their own relevance", %{
    conn: conn,
    owner: owner,
    space: space
  } do
    community = create_topic!(owner, space, "community", "Community")

    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries/entries/entry-place")

    assert has_element?(view, testid("entry-topic-detail-#{community.id}"))
    assert has_element?(view, testid("entry-topic-dismiss-#{community.id}"))

    view |> element(testid("entry-topic-dismiss-#{community.id}")) |> render_click()
    refute has_element?(view, testid("entry-topic-detail-#{community.id}"))

    view |> element(testid("entry-topic-add-open")) |> render_click()

    view
    |> form(testid("entry-topic-form"),
      entry_topic: %{relevancy: "6", topic_id: community.id}
    )
    |> render_submit()

    assert has_element?(view, testid("entry-topic-detail-#{community.id}"), "6/10")
    assert has_element?(view, testid("entry-topic-remove-#{community.id}"))
  end

  test "admins tune automatic matching with aliases and per-topic switches", %{
    conn: conn,
    owner: owner,
    space: space
  } do
    local = create_topic!(owner, space, "local-community", "Local community")

    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries/topic-matching")

    assert has_element?(view, testid("topic-matching-page"))
    assert has_element?(view, testid("topic-matching-rule-local-community"))

    view |> element(testid("topic-matching-expand-local-community")) |> render_click()

    view
    |> form(testid("topic-matching-alias-form-local-community"),
      topic_alias: %{value: "local-first"}
    )
    |> render_submit()

    assert has_element?(view, testid("topic-matching-alias-local-community"))

    render_patch(view, ~p"/#{space.slug}/libraries")
    assert has_element?(view, testid("entry-topic-entry-video-#{local.id}"))

    render_patch(view, ~p"/#{space.slug}/libraries/topic-matching")

    view
    |> element(testid("topic-matching-rule-toggle-local-community"))
    |> render_click()

    assert has_element?(
             view,
             testid("topic-matching-rule-toggle-local-community") <> ~s([aria-checked="false"])
           )
  end

  test "owners create a type, configure fields, and cannot delete a used type", %{
    conn: conn,
    space: space
  } do
    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries/types/new")

    view |> element(testid("template-select-custom")) |> render_click()

    view
    |> form(testid("type-create-form"),
      type: %{
        description: "People worth calling",
        entry_creation_permission: "members",
        name: "Useful people"
      }
    )
    |> render_submit()

    assert_patch(view, ~p"/#{space.slug}/libraries/types/useful-people/settings")

    view
    |> form(testid("field-form"),
      field: %{label: "Role", required: "false", type: "text"}
    )
    |> render_submit()

    assert has_element?(view, testid("schema-field-role"))

    view |> element(testid("field-edit-role")) |> render_click()

    assert_push_event(view, "field:focus-label", %{})
    assert has_element?(view, "#field-label[value=\"Role\"]")

    {:ok, used_view, _html} =
      live(conn, ~p"/#{space.slug}/libraries/types/place/settings")

    assert has_element?(used_view, testid("type-delete-blocked"))
    assert has_element?(used_view, testid("type-delete") <> "[disabled]")
  end

  test "type schemas remain portable", %{conn: conn, space: space} do
    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries/types/external-media/settings")

    assert has_element?(view, testid("portable-schema"))
    assert has_element?(view, "#library-schema-json[readonly]")

    blueprint =
      State.new()
      |> State.find_type("contact")
      |> Schema.export()

    {:ok, import_view, _html} = live(conn, ~p"/#{space.slug}/libraries/types/new")

    import_view
    |> form(testid("schema-import-form"), schema: %{json: blueprint})
    |> render_submit()

    assert has_element?(import_view, testid("type-create-form"))
  end

  test "members can add entries but cannot open Library settings", %{space: space} do
    member = generate(user())
    add_membership(space, member, :member)
    grant_active_telegram_access(space, member)

    conn = Phoenix.ConnTest.build_conn() |> log_in(member)
    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries")

    assert has_element?(view, testid("entry-create-open"))
    refute has_element?(view, testid("library-settings-open"))

    assert {:error,
            {:live_redirect,
             %{
               to: redirect_path,
               flash: %{"error" => "Only space administrators can manage Library settings."}
             }}} =
             live(conn, ~p"/#{space.slug}/libraries/topic-matching")

    assert redirect_path == ~p"/#{space.slug}/libraries"
  end

  test "topic pages link back to the matching Library filter", %{
    conn: conn,
    owner: owner,
    space: space
  } do
    topic = create_topic!(owner, space, "social-dance", "Social dance")

    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/topics/#{topic.slug}")

    assert has_element?(
             view,
             testid("tag-library-link") <>
               ~s([href="/#{space.slug}/libraries?topics=#{topic.slug}"])
           )
  end

  defp create_topic!(owner, space, slug, name) do
    {:ok, topic} = Tags.create_tag(slug, name, scope: scope(owner, space))
    topic
  end

  defp external_media_get("https://www.googleapis.com/youtube/v3/videos", opts) do
    {creator, description, duration, title} =
      case opts[:params][:id] do
        "UuU-Go8GoeY" ->
          {"Second channel", "Second video description", "PT4M5S", "Second title"}

        _video_id ->
          {"Fetched channel", "Fetched video description", "PT1H2M3S", "Fetched title"}
      end

    {:ok,
     %Req.Response{
       status: 200,
       body: %{
         "items" => [
           %{
             "contentDetails" => %{"duration" => duration},
             "snippet" => %{
               "channelTitle" => creator,
               "description" => description,
               "thumbnails" => %{"high" => %{"url" => "https://example.test/cover.jpg"}},
               "title" => title
             }
           }
         ]
       }
     }}
  end

  defp external_media_get("https://www.googleapis.com/youtube/v3/playlists", _opts) do
    {:ok,
     %Req.Response{
       status: 200,
       body: %{
         "items" => [
           %{
             "contentDetails" => %{"itemCount" => 24},
             "snippet" => %{
               "channelTitle" => "Fetched playlist channel",
               "description" => "Fetched playlist description",
               "thumbnails" => %{
                 "high" => %{"url" => "https://example.test/playlist.jpg"}
               },
               "title" => "Fetched playlist"
             }
           }
         ]
       }
     }}
  end

  defp external_media_get("https://www.googleapis.com/youtube/v3/playlistItems", _opts) do
    {:ok,
     %Req.Response{
       status: 200,
       body: %{
         "items" => [
           %{
             "snippet" => %{
               "resourceId" => %{"videoId" => "playlist-video-one"},
               "title" => "First playlist video"
             }
           },
           %{
             "snippet" => %{
               "resourceId" => %{"videoId" => "playlist-video-two"},
               "title" => "Second playlist video"
             }
           }
         ]
       }
     }}
  end

  defp external_media_get("https://soundcloud.com/oembed", _opts) do
    {:ok,
     %Req.Response{
       status: 200,
       body: %{
         "author_name" => "Fetched artist",
         "description" => "Fetched track description",
         "title" => "Fetched track"
       }
     }}
  end

  defp scope(actor, tenant), do: %Scope{actor: actor, tenant: tenant}

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false
    )
  end

  defp log_in(conn, user) do
    {:ok, token, _claims} = Jwt.token_for_user(user)
    user = Ash.Resource.set_metadata(user, %{token: token})

    conn
    |> init_test_session(%{})
    |> AuthHelpers.store_in_session(user)
  end
end
