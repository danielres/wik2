defmodule WikWeb.PageLiveRenameTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Accounts.Membership
  alias Wik.Scope
  alias Wik.Wiki
  alias Wik.Wiki.PageTree

  setup %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    scope = %Scope{actor: owner, tenant: space}
    {:ok, original_node, original_page} = Wiki.ensure_page_and_node_at_path("home", scope: scope)

    page_tree = Wiki.load_page_tree(scope)
    {:ok, _page_tree} = PageTree.add_child(page_tree, nil, "existing", "Existing", scope: scope)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/wiki/home")

    render_async(view)

    %{
      original_node: original_node,
      original_page: original_page,
      scope: scope,
      space: space,
      view: view
    }
  end

  test "page manager can open the rename dialog", %{view: view} do
    refute has_element?(view, testid("page-title-edit"))
    assert has_element?(view, ~s(button[phx-click="edit_mode:toggle"]))

    render_click(element(view, ~s(button[phx-click="edit_mode:toggle"])))

    assert has_element?(view, testid("page-title-edit"))
    render_click(element(view, testid("page-title-edit")))

    assert has_element?(view, testid("page-rename-dialog"))
    assert has_element?(view, testid("page-rename-form"))
    assert has_element?(view, testid("page-rename-title") <> ~s([value="Home"]))
  end

  test "rename form previews the generated slug", %{view: view} do
    open_rename_form(view)

    render_change(
      form(view, testid("page-rename-form"),
        form: %{"slug" => "draft-title", "title" => "Draft Title"}
      )
    )

    assert has_element?(view, testid("page-rename-auto-slug-draft-title"))
  end

  test "page manager can cancel and reset the rename form", %{view: view} do
    open_rename_form(view)
    assert has_element?(view, testid("page-rename-form"))

    render_click(element(view, testid("page-rename-cancel")))
    refute has_element?(view, testid("page-rename-form"))

    assert has_element?(view, testid("page-title-edit"))
    render_click(element(view, testid("page-title-edit")))
    assert has_element?(view, testid("page-rename-title") <> ~s([value="Home"]))
  end

  test "rename form rejects a duplicate sibling slug", %{view: view} do
    open_rename_form(view)
    assert has_element?(view, testid("page-rename-form"))

    render_submit(
      form(view, testid("page-rename-form"), form: %{"slug" => "existing", "title" => "Existing"})
    )

    assert has_element?(view, testid("page-rename-error-nodes"))
  end

  test "successful rename navigates and preserves the page", %{
    original_node: original_node,
    original_page: original_page,
    scope: scope,
    space: space,
    view: view
  } do
    open_rename_form(view)
    assert has_element?(view, testid("page-rename-form"))

    render_submit(
      form(view, testid("page-rename-form"),
        form: %{"slug" => "start-here", "title" => "Start Here"}
      )
    )

    assert_redirect(view, ~p"/#{space.slug}/wiki/start-here")

    {renamed_node, renamed_page} =
      Wiki.load_page_and_node_by_path("start-here", scope: scope)

    assert renamed_node.id == original_node.id
    assert renamed_node.title == "Start Here"
    assert renamed_page.id == original_page.id
    assert {nil, nil} = Wiki.load_page_and_node_by_path("home", scope: scope)
  end

  defp open_rename_form(view) do
    assert has_element?(view, ~s(button[phx-click="edit_mode:toggle"]))
    render_click(element(view, ~s(button[phx-click="edit_mode:toggle"])))

    assert has_element?(view, testid("page-title-edit"))
    render_click(element(view, testid("page-title-edit")))

    assert has_element?(view, testid("page-rename-form"))
  end

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
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
