defmodule WikWeb.PageLiveTopicsTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Accounts.Membership
  alias Wik.Blocks
  alias Wik.Scope
  alias Wik.Tags
  alias Wik.Wiki

  test "page manager can add and remove a topic from the page aside", %{conn: conn} do
    assert_page_topic_management_works(conn)
  end

  test "empty main area shows one add block button in edit mode", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/wiki/home")

    render_async(view)

    render_click(element(view, ~s(button[phx-click="edit_mode:toggle"])))

    add_block_buttons =
      view
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query(~s(button[phx-click="block:add_start"]))

    assert Enum.count(add_block_buttons) == 1
  end

  test "main area with blocks shows top and bottom add block buttons in edit mode", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    owner_scope = scope(owner, space)
    {:ok, _node, page} = Wiki.ensure_page_and_node_at_path("home", scope: owner_scope)

    assert {:ok, _block} =
             Blocks.create_user_owned_block_on_page(
               page,
               %{data: %{"text" => "Hello"}, type: :text},
               scope: owner_scope
             )

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/wiki/home")

    render_async(view)

    render_click(element(view, ~s(button[phx-click="edit_mode:toggle"])))

    add_block_buttons =
      view
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query(~s(button[phx-click="block:add_start"]))

    assert Enum.count(add_block_buttons) == 2
  end

  defp assert_page_topic_management_works(conn) do
    owner = generate(user())
    space = generate(space(author: owner))
    membership = add_membership(space, owner, :owner)
    owner_scope = scope(owner, space)
    {:ok, dance} = Tags.create_tag("dance", "Dance", scope: owner_scope)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/wiki/home")

    render_async(view)

    render_click(element(view, ~s(button[phx-click="edit_mode:toggle"])))

    assert has_element?(view, testid("page-topics"))
    assert has_element?(view, testid("page-topic-list"))
    assert has_element?(view, testid("page-topic-add"))

    render_click(element(view, testid("page-topic-add")))

    modal_html =
      view
      |> element("#page-topic-inline-modal_portal")
      |> render()

    assert modal_html =~ ~s(id="page-topic-inline-form")

    render_hook(view, "page_topic:submit", %{
      "page_topic" => %{
        "tag_id" => dance.id,
        "relevancy_level" => "7"
      }
    })

    {_node, page} = Wiki.load_page_and_node_by_path("home", scope: owner_scope)

    assert {:ok, [tagging]} = Tags.list_taggings(page, scope: owner_scope)
    assert tagging.dimensions == %{"relevancy" => 7}
    assert tagging.tagged_by_membership_id == membership.id

    assert has_element?(view, testid("page-topic-#{dance.id}"))
    assert has_element?(view, testid("page-topic-relevancy-#{dance.id}"))

    render_hook(view, "page_topic:remove", %{"tag_id" => dance.id})

    assert {:ok, []} = Tags.list_taggings(page, scope: owner_scope)
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

  defp scope(actor, tenant), do: %Scope{actor: actor, tenant: tenant}
end
