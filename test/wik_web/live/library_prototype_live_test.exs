defmodule WikWeb.LibraryPrototypeLiveTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Accounts.Membership
  alias WikWeb.LibraryPrototypeLive.Schema
  alias WikWeb.LibraryPrototypeLive.State

  setup %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    %{conn: log_in(conn, owner), owner: owner, space: space}
  end

  test "renders general collections and their field-derived entries", %{conn: conn, space: space} do
    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries")

    assert has_element?(view, testid("library-prototype-page"))
    assert has_element?(view, testid("collection-card-places"))
    assert has_element?(view, testid("collection-card-contacts"))
    assert has_element?(view, testid("collection-card-videos"))
    assert has_element?(view, testid("collection-card-music"))

    view |> element(testid("collection-card-places")) |> render_click()

    assert_patch(view, ~p"/#{space.slug}/libraries/places")
    assert has_element?(view, testid("library-entry-entry-place"))
    refute has_element?(view, testid("entry-media-entry-place"))
    assert has_element?(view, testid("entry-create-open"))
  end

  test "owners create a custom collection and configure its schema", %{conn: conn, space: space} do
    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries/new")

    refute has_element?(view, ~s([data-testid^="collection-nav-"][aria-current="page"]))

    view |> element(testid("template-select-custom")) |> render_click()

    assert has_element?(view, ~s(#collection_name[phx-hook="CapitalizeFirstLetter"]))

    assert has_element?(
             view,
             ~s(input#collection_description[phx-hook="CapitalizeFirstLetter"])
           )

    refute has_element?(view, ~s([data-testid="entry-creation-permission-members"]:checked))
    refute has_element?(view, ~s([data-testid="entry-creation-permission-admins"]:checked))

    view
    |> form(testid("collection-create-form"),
      collection: %{
        description: "People worth calling",
        entry_creation_permission: "members",
        name: "Useful people"
      }
    )
    |> render_submit()

    assert_patch(view, ~p"/#{space.slug}/libraries/useful-people")
    assert has_element?(view, testid("entry-create-open"))

    view |> element(testid("collection-settings-open")) |> render_click()

    assert has_element?(view, ~s(#collection_name[phx-hook="CapitalizeFirstLetter"]))

    assert has_element?(
             view,
             ~s(input#collection_description[phx-hook="CapitalizeFirstLetter"])
           )

    view
    |> form(testid("field-form"),
      field: %{label: "Email", required: "true", type: "email"}
    )
    |> render_submit()

    assert has_element?(view, testid("schema-field-email"))
  end

  test "field options are shown only for select fields", %{conn: conn, space: space} do
    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries/videos/settings")

    refute has_element?(view, "#field_options")

    view
    |> form(testid("field-form"), field: %{type: "select"})
    |> render_change()

    assert has_element?(view, "#field_options")

    view
    |> form(testid("field-form"), field: %{type: "text"})
    |> render_change()

    refute has_element?(view, "#field_options")
  end

  test "owners restrict who can add entries", %{conn: conn, space: space} do
    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries/videos/settings")

    assert has_element?(view, testid("collection-permissions"))
    assert has_element?(view, ~s([data-testid="entry-creation-permission-members"]:checked))

    view
    |> element(testid("entry-creation-permission-admins"))
    |> render_click()

    assert has_element?(view, ~s([data-testid="entry-creation-permission-admins"]:checked))

    view |> element(testid("collection-nav-videos")) |> render_click()

    assert_patch(view, ~p"/#{space.slug}/libraries/videos")
    assert has_element?(view, ~s([data-testid="entry-create-open"].btn-accent))
  end

  test "schema JSON is available in settings and can be imported as a reviewed collection draft",
       %{
         conn: conn,
         space: space
       } do
    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/libraries/videos")

    refute has_element?(view, testid("schema-view-open"))
    refute has_element?(view, testid("templates-manage-open"))
    assert has_element?(view, testid("entry-media-entry-video"))

    assert has_element?(
             view,
             ~s(#collection-title + [data-testid="collection-settings-open"])
           )

    refute has_element?(
             view,
             ~s([data-testid="library-navigation"] [data-testid="collection-settings-open"])
           )

    view |> element(testid("collection-settings-open")) |> render_click()

    assert_patch(view, ~p"/#{space.slug}/libraries/videos/settings")
    refute has_element?(view, testid("collection-settings-open"))
    refute has_element?(view, testid("template-save"))

    assert has_element?(view, testid("portable-schema"))
    assert has_element?(view, testid("schema-copy"))
    assert has_element?(view, "#library-schema-json[readonly]")

    blueprint =
      State.new()
      |> State.find_collection("contacts")
      |> Schema.export()

    {:ok, import_view, _html} = live(conn, ~p"/#{space.slug}/libraries/new")

    import_view
    |> form(testid("schema-import-form"), schema: %{json: blueprint})
    |> render_submit()

    assert has_element?(import_view, testid("collection-create-form"))
    assert has_element?(import_view, testid("collection-create-submit"))

    refute has_element?(
             import_view,
             ~s([data-testid="entry-creation-permission-members"]:checked)
           )

    refute has_element?(
             import_view,
             ~s([data-testid="entry-creation-permission-admins"]:checked)
           )
  end

  test "members create and manage their own entries", %{space: space} do
    member = generate(user())
    add_membership(space, member, :member)
    grant_active_telegram_access(space, member)

    {:ok, view, _html} =
      Phoenix.ConnTest.build_conn()
      |> log_in(member)
      |> live(~p"/#{space.slug}/libraries/places")

    refute has_element?(view, testid("collection-settings-open"))
    refute has_element?(view, testid("schema-view-open"))
    assert has_element?(view, testid("entry-create-open"))

    view |> element(testid("entry-create-open")) |> render_click()

    view
    |> form(testid("entry-form"),
      entry: %{
        location: "Berlin",
        name: "My dance studio",
        notes: "",
        phone: "",
        website: ""
      }
    )
    |> render_submit()

    assert has_element?(view, "#library-entries [data-testid^='entry-open-entry-']:has(.badge)")

    view
    |> element("#library-entries [data-testid^='entry-open-entry-']:has(.badge)")
    |> render_click()

    assert has_element?(view, "[data-testid^='entry-edit-entry-']")
    assert has_element?(view, "[data-testid^='entry-delete-entry-']")
  end

  test "members cannot manage system or other members' entries, including forged events", %{
    space: space
  } do
    member = generate(user())
    add_membership(space, member, :member)
    grant_active_telegram_access(space, member)

    {:ok, view, _html} =
      Phoenix.ConnTest.build_conn()
      |> log_in(member)
      |> live(~p"/#{space.slug}/libraries/videos?#{%{entry: "entry-video"}}")

    refute has_element?(view, testid("entry-edit-entry-video"))
    refute has_element?(view, testid("entry-delete-entry-video"))

    render_click(view, "entry:delete", %{"entry_id" => "entry-video"})

    assert has_element?(view, testid("library-entry-entry-video"))
    refute has_element?(view, testid("library-entry-detail-entry-video"))
  end

  test "admins can manage every entry and collection schema", %{space: space} do
    admin = generate(user())
    add_membership(space, admin, :admin)
    grant_active_telegram_access(space, admin)

    {:ok, view, _html} =
      Phoenix.ConnTest.build_conn()
      |> log_in(admin)
      |> live(~p"/#{space.slug}/libraries/videos?#{%{entry: "entry-video"}}")

    assert has_element?(view, testid("collection-settings-open"))
    assert has_element?(view, testid("entry-edit-entry-video"))
    assert has_element?(view, testid("entry-delete-entry-video"))
  end

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
