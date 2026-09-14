defmodule WikWeb.PageLiveLibraryEntriesTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Accounts.Membership

  setup %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))

    Ash.create!(
      Membership,
      %{space_id: space.id, type: :owner, user_id: owner.id},
      authorize?: false,
      domain: Wik.Accounts
    )

    %{conn: log_in(conn, owner), space: space}
  end

  test "inserts existing Library entries, allows duplicates, and opens entry details", %{
    conn: conn,
    space: space
  } do
    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/wiki/home")

    enter_edit_mode(view)
    open_add_block(view, "top")

    assert has_element?(view, testid("library-type-place"), "Place")

    view |> element(testid("library-type-place")) |> render_click()

    assert has_element?(view, testid("library-entry-chooser"))
    assert has_element?(view, "#library-entry-search-form")

    view |> element(testid("library-entry-back")) |> render_click()

    assert has_element?(view, testid("add-block-dialog") <> ".modal-open")

    view |> element(testid("library-type-place")) |> render_click()

    view
    |> form("#library-entry-search-form", library_search: %{query: "Spreeacker"})
    |> render_change()

    assert has_element?(view, testid("library-picker-entry-entry-place"), "Spreeacker")
    refute has_element?(view, testid("library-picker-entry-entry-place-garden"))

    view |> element(testid("library-entry-select-entry-place")) |> render_click()

    refute has_element?(view, testid("library-entry-modal") <> ".modal-open")
    assert placement_count(view) == 1

    open_add_block(view, "top")
    view |> element(testid("library-type-place")) |> render_click()
    view |> element(testid("library-entry-select-entry-place")) |> render_click()

    assert placement_count(view) == 2

    leave_edit_mode(view)

    view
    |> element(~s(#library-top-placements > div:first-child [data-testid^="library-entry-open-"]))
    |> render_click()

    assert has_element?(view, testid("library-entry-modal") <> ".modal-open")
    assert has_element?(view, testid("library-entry-detail-entry-place"))
  end

  test "creates, inserts, and edits one shared entry through duplicate cards", %{
    conn: conn,
    space: space
  } do
    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/wiki/home")

    enter_edit_mode(view)
    open_add_block(view, "top")
    view |> element(testid("library-type-contact")) |> render_click()
    view |> element(testid("library-entry-create-new")) |> render_click()

    assert has_element?(view, testid("library-entry-create-form"))

    view
    |> form(testid("library-entry-create-form"), entry: %{name: ""})
    |> render_submit()

    assert has_element?(view, testid("library-entry-error"))
    assert placement_count(view) == 0

    view
    |> form(testid("library-entry-create-form"),
      entry: %{
        email: "hello@example.test",
        name: "Prototype contact",
        notes: "Created from a page",
        organization: "Wik",
        phone: "",
        role: "Organizer",
        website: ""
      }
    )
    |> render_submit()

    assert placement_count(view) == 1
    assert has_element?(view, ~s([data-testid^="library-entry-card-"] h3), "Prototype contact")

    open_add_block(view, "top")
    view |> element(testid("library-type-contact")) |> render_click()

    view
    |> element(~s(button[aria-label="Insert Prototype contact"]))
    |> render_click()

    assert placement_count(view) == 2

    assert has_element?(
             view,
             ~s(#library-top-placements > div:first-child [data-testid^="library-entry-move-up-"][disabled])
           )

    assert has_element?(
             view,
             ~s|#library-top-placements > div:first-child [data-testid^="library-entry-move-down-"]:not([disabled])|
           )

    view
    |> element(~s(#library-top-placements > div:first-child [data-testid^="library-entry-edit-"]))
    |> render_click()

    assert has_element?(view, testid("library-entry-modal") <> ".modal-open")
    assert has_element?(view, testid("library-entry-shared-edit-notice"))
    assert has_element?(view, testid("library-entry-edit-form"))
    refute has_element?(view, "#library-top-placements form")

    view
    |> form(testid("library-entry-edit-form"),
      entry: %{
        email: "updated@example.test",
        name: "Updated shared contact",
        notes: "Updated from a page",
        organization: "Wik",
        phone: "",
        role: "Organizer",
        website: ""
      }
    )
    |> render_submit()

    assert has_element?(view, ~s([data-testid^="library-entry-detail-"]))
    assert card_title_count(view, "Updated shared contact") == 2

    view
    |> element(
      ~s(#library-top-placements > div:first-child [data-testid^="library-entry-remove-"])
    )
    |> render_click()

    assert placement_count(view) == 1
  end

  defp enter_edit_mode(view) do
    view |> element(~s(button[phx-click="edit_mode:toggle"])) |> render_click()
  end

  defp leave_edit_mode(view), do: enter_edit_mode(view)

  defp open_add_block(view, position) do
    view
    |> element(~s(button[phx-click="block:add_start"][phx-value-position="#{position}"]))
    |> render_click()
  end

  defp placement_count(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(~s([data-testid^="library-entry-block-"]))
    |> Enum.count()
  end

  defp card_title_count(view, title) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(~s([data-testid^="library-entry-card-"] h3))
    |> Enum.count(&(LazyHTML.text(&1) =~ title))
  end

  defp log_in(conn, user) do
    {:ok, token, _claims} = Jwt.token_for_user(user)
    user = Ash.Resource.set_metadata(user, %{token: token})

    conn
    |> init_test_session(%{})
    |> AuthHelpers.store_in_session(user)
  end
end
