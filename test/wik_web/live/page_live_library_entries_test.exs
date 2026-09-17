defmodule WikWeb.PageLiveLibraryEntriesTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Accounts.Membership
  alias Wik.Blocks
  alias Wik.Library
  alias Wik.Wiki
  alias WikWeb.LibraryLive.ExternalMedia
  alias WikWeb.LibraryLive.State

  setup %{conn: conn} do
    previous_external_media_config = Application.get_env(:wik, ExternalMedia, [])

    Application.put_env(:wik, ExternalMedia,
      http_get: &external_media_get/2,
      youtube_api_key: "test-youtube-api-key"
    )

    on_exit(fn ->
      Application.put_env(:wik, ExternalMedia, previous_external_media_config)
    end)

    owner = generate(user())
    space = generate(space(author: owner))

    Ash.create!(
      Membership,
      %{space_id: space.id, type: :owner, user_id: owner.id},
      authorize?: false,
      domain: Wik.Accounts
    )

    %{conn: log_in(conn, owner), owner: owner, space: space}
  end

  test "inserts a Library block only after the entry flow is complete", %{
    conn: conn,
    owner: owner,
    space: space
  } do
    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/wiki/home")

    enter_edit_mode(view)
    open_add_block(view, "top")

    assert has_element?(view, testid("library-type-contact"), "Contact")

    view |> element(testid("library-type-contact")) |> render_click()

    refute has_element?(view, ~s(form[id^="edit-block-form-"]))
    refute has_element?(view, ~s([data-testid^="library-entry-card-"]))
    assert has_element?(view, testid("library-entry-modal") <> ".modal-open")
    assert has_element?(view, testid("library-entry-picker-results"))
    assert view_page(view).block_placements == []

    view |> element(testid("library-entry-modal-close")) |> render_click()

    refute has_element?(view, testid("library-entry-modal") <> ".modal-open")
    assert view_page(view).block_placements == []

    open_add_block(view, "top")
    view |> element(testid("library-type-contact")) |> render_click()

    view
    |> element(testid("library-entry-picker-create"))
    |> render_click()

    assert has_element?(view, testid("library-entry-modal") <> ".modal-open")
    assert has_element?(view, testid("library-entry-create-form"))

    view
    |> form(testid("library-entry-create-form"),
      entry: %{
        email: "hello@example.test",
        name: "Persistent contact",
        notes: "Created from a page",
        organization: "Wik",
        phone: "",
        role: "Organizer",
        website: ""
      }
    )
    |> render_submit()

    refute has_element?(view, testid("library-entry-modal") <> ".modal-open")

    assert {:ok, [entry]} = Library.list_entries(scope: scope(owner, space))

    assert eventually_has_element?(
             view,
             ~s([data-testid^="library-entry-card-"]),
             "Persistent contact"
           )

    [placement] = view_page(view).block_placements
    assert placement.block.type == :library_entry

    assert placement.block.library_entry_reference.entry_id == entry.id
    assert placement.block.library_entry_reference.entry.id == entry.id

    assert {:ok, %{entry_id: entry_id}} =
             Library.get_block_reference(placement.block.id, scope: scope(owner, space))

    assert entry_id == entry.id

    assert {:error, "This entry is used by 1 block. Remove that block first."} =
             State.delete_entry(
               State.new(scope(owner, space)),
               entry.type_id,
               entry.id,
               owner.id,
               true
             )
  end

  test "duplicate standard blocks share an entry and shared editing stays in a modal", %{
    conn: conn,
    owner: owner,
    space: space
  } do
    scope = scope(owner, space)
    :ok = Library.Provisioning.ensure_default_types(scope)
    {:ok, contact_type} = Library.get_entry_type_by_slug("contact", scope: scope)

    {:ok, entry} =
      Library.create_entry(
        contact_type,
        %{"name" => "Shared contact"},
        nil,
        scope: scope
      )

    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/wiki/home")

    add_library_block(view, entry, "top")
    add_library_block(view, entry, "bottom")

    assert eventually_count(view, ~s([data-testid^="library-entry-card-"])) == 2

    assert Enum.all?(view_page(view).block_placements, fn placement ->
             placement.block.library_entry_reference.entry_id == entry.id
           end)

    [placement | _rest] = view_page(view).block_placements

    telemetry_handler_id =
      "library-block-render-#{System.unique_integer([:positive, :monotonic])}"

    :ok =
      :telemetry.attach(
        telemetry_handler_id,
        Wik.Repo.config()[:telemetry_prefix] ++ [:query],
        fn _event, _measurements, metadata, test_pid ->
          if metadata.source == "library_block_references" do
            send(test_pid, :library_block_reference_query)
          end
        end,
        self()
      )

    on_exit(fn -> :telemetry.detach(telemetry_handler_id) end)

    assert {:ok, _reference} =
             Library.get_block_reference(placement.block.id, scope: scope)

    assert_received :library_block_reference_query

    render_component(&WikWeb.Components.Block.Types.LibraryEntry.render/1, %{
      block: placement.block,
      library_state: :sys.get_state(view.pid).socket.assigns.library_state
    })

    refute_received :library_block_reference_query

    enter_edit_mode(view)

    view
    |> element("#block-#{placement.block.id} .BLOCK")
    |> render_click()

    assert has_element?(view, testid("library-entry-dialog") <> ".modal-open")
    assert has_element?(view, testid("entry-form"))
    refute has_element?(view, "#active-block-editor-#{placement.block.id}")

    view |> element(testid("library-modal-close")) |> render_click()
    toggle_edit_mode(view)

    view
    |> element(testid("library-entry-open-#{placement.block.id}"))
    |> render_click()

    assert has_element?(view, testid("library-entry-dialog") <> ".modal-open")
    assert has_element?(view, testid("entry-edit-#{entry.id}"))
    refute has_element?(view, testid("entry-delete-#{entry.id}"))
    assert has_element?(view, testid("entry-topics"))

    view |> element(testid("entry-topic-add-open")) |> render_click()
    assert has_element?(view, testid("entry-topic-form"))
    view |> element(testid("entry-topic-cancel")) |> render_click()

    view
    |> element(testid("entry-edit-#{entry.id}"))
    |> render_click()

    assert has_element?(view, testid("library-entry-dialog") <> ".modal-open")
    assert has_element?(view, testid("entry-form"))
    assert has_element?(view, testid("entry-delete-#{entry.id}"))
    refute has_element?(view, testid("library-entry-shared-edit-notice"))

    view |> element(testid("entry-delete-#{entry.id}")) |> render_click()
    assert has_element?(view, testid("entry-modal-error"))

    view
    |> form(testid("entry-form"),
      entry: %{
        email: "",
        name: "Updated shared contact",
        notes: "",
        organization: "",
        phone: "",
        role: "",
        website: ""
      }
    )
    |> render_submit()

    assert eventually_count(
             view,
             ~s([data-testid^="library-entry-card-"] h3),
             "Updated shared contact"
           ) == 2
  end

  test "reports a missing reference when editing an orphaned Library block", %{
    conn: conn,
    owner: owner,
    space: space
  } do
    scope = scope(owner, space)
    {:ok, _node, page} = Wiki.ensure_page_and_node_at_path("home", scope: scope)

    assert {:ok, block} =
             Blocks.create_space_owned_block_on_page(
               space,
               page,
               %{type: :library_entry},
               scope: scope
             )

    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/wiki/home")

    assert has_element?(view, testid("library-entry-missing"))

    enter_edit_mode(view)

    view
    |> element("#block-#{block.id} .BLOCK")
    |> render_click()

    assert has_element?(view, "#flash-error", "That Library entry is no longer available")
    refute has_element?(view, testid("library-entry-dialog") <> ".modal-open")
  end

  test "uses the shared external media form behavior from a wiki entry modal", %{
    conn: conn,
    owner: owner,
    space: space
  } do
    scope = scope(owner, space)
    :ok = Library.Provisioning.ensure_default_types(scope)
    {:ok, media_type} = Library.get_entry_type_by_slug("external-media", scope: scope)

    {:ok, entry} =
      Library.create_entry(
        media_type,
        %{
          "creator" => "",
          "duration" => "",
          "media" => "https://youtu.be/UuU-Go8GoeY",
          "notes" => "",
          "title" => "Original title"
        },
        nil,
        scope: scope
      )

    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/wiki/home")
    add_library_block(view, entry, "top", "external-media")

    [placement] = view_page(view).block_placements

    view
    |> element(testid("library-entry-open-#{placement.block.id}"))
    |> render_click()

    view |> element(testid("entry-edit-#{entry.id}")) |> render_click()

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
  end

  defp add_library_block(view, entry, position, type_slug \\ "contact") do
    enter_edit_mode(view)
    open_add_block(view, position)
    view |> element(testid("library-type-#{type_slug}")) |> render_click()

    view
    |> element(testid("library-entry-picker-select-#{entry.id}"))
    |> render_click()
  end

  defp enter_edit_mode(view) do
    toggle_edit_mode(view)
  end

  defp toggle_edit_mode(view),
    do: view |> element(~s(button[phx-click="edit_mode:toggle"])) |> render_click()

  defp open_add_block(view, position) do
    view
    |> element(~s(button[phx-click="block:add_start"][phx-value-position="#{position}"]))
    |> render_click()
  end

  defp eventually_has_element?(view, selector, text, attempts \\ 5)
  defp eventually_has_element?(_view, _selector, _text, 0), do: false

  defp eventually_has_element?(view, selector, text, attempts) do
    if has_element?(view, selector, text) do
      true
    else
      eventually_has_element?(view, selector, text, attempts - 1)
    end
  end

  defp eventually_count(view, selector, text \\ nil) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(selector)
    |> Enum.count(fn node -> is_nil(text) or LazyHTML.text(node) =~ text end)
  end

  defp external_media_get("https://www.googleapis.com/youtube/v3/videos", _opts) do
    {:ok,
     %Req.Response{
       status: 200,
       body: %{
         "items" => [
           %{
             "contentDetails" => %{"duration" => "PT1H2M3S"},
             "snippet" => %{
               "channelTitle" => "Fetched channel",
               "description" => "Fetched video description",
               "thumbnails" => %{"high" => %{"url" => "https://example.test/cover.jpg"}},
               "title" => "Fetched title"
             }
           }
         ]
       }
     }}
  end

  defp view_page(view), do: :sys.get_state(view.pid).socket.assigns.page

  defp scope(actor, tenant), do: %Wik.Scope{actor: actor, tenant: tenant}

  defp log_in(conn, user) do
    {:ok, token, _claims} = Jwt.token_for_user(user)
    user = Ash.Resource.set_metadata(user, %{token: token})

    conn
    |> init_test_session(%{})
    |> AuthHelpers.store_in_session(user)
  end
end
