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

  test "topic modal expands voters and manages the current member contribution", %{
    conn: conn
  } do
    owner = generate(user())
    member = generate(user())
    space = generate(space(author: owner))
    owner_membership = add_membership(space, owner, :owner)
    member_membership = add_membership(space, member, :member)
    owner_scope = scope(owner, space)
    {:ok, dance} = Tags.create_tag("dance", "Dance", scope: owner_scope)
    {:ok, _node, page} = Wiki.ensure_page_and_node_at_path("home", scope: owner_scope)

    assert {:ok, owner_tagging} =
             Tags.upsert_tagging(
               page,
               owner_membership,
               dance.id,
               %{dimensions: %{"relevancy" => 7}},
               scope: owner_scope
             )

    member_tagging =
      generate(
        tagging(
          dimensions: %{"relevancy" => 5},
          membership: member_membership,
          space: space,
          tag: dance,
          taggable_id: page.id,
          taggable_type: "page"
        )
      )

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/wiki/home")

    render_async(view)
    render_click(element(view, ~s(button[phx-click="edit_mode:toggle"])))
    render_click(element(view, testid("page-topic-add")))

    assert modal_has_element?(view, testid("page-topic-modal-topic-#{dance.id}"))
    assert modal_has_element?(view, testid("page-topic-modal-average-#{dance.id}"))
    assert modal_has_element?(view, testid("page-topic-modal-voters-#{dance.id}"))

    assert modal_has_element?(
             view,
             "#{testid("page-topic-modal-topic-#{dance.id}")}.collapse.collapse-arrow"
           )

    assert modal_has_element?(
             view,
             "#page-topic-inline-modal-topic-toggle-#{dance.id}[type=\"checkbox\"]"
           )

    assert modal_has_element?(view, testid("page-topic-modal-details-#{dance.id}"))
    assert modal_has_element?(view, testid("page-topic-modal-contribution-#{owner_tagging.id}"))
    assert modal_has_element?(view, testid("page-topic-modal-contribution-#{member_tagging.id}"))
    assert modal_has_element?(view, testid("page-topic-modal-edit-#{owner_tagging.id}"))
    refute modal_has_element?(view, testid("page-topic-modal-edit-#{member_tagging.id}"))

    assert modal_has_element?(
             view,
             "#{testid("page-topic-modal-edit-#{owner_tagging.id}")}[phx-click=\"page_topic:edit_start\"]"
           )

    render_hook(view, "page_topic:edit_start", %{"tagging_id" => owner_tagging.id})

    assert modal_has_element?(view, testid("page-topic-edit-preview"))
    assert modal_has_element?(view, "#page-topic-inline-edit-relevancy")
    refute modal_has_element?(view, "#page-topic-inline-edit-relevancy[disabled]")

    assert modal_has_element?(
             view,
             "#page-topic-inline-edit-remove[phx-click=\"page_topic:edit_remove\"]"
           )

    assert modal_has_element?(view, "#page-topic-inline-edit-save[type=\"submit\"]")

    assert modal_has_element?(
             view,
             "#page-topic-inline-edit-back[phx-click=\"page_topic:edit_cancel\"]"
           )

    render_hook(view, "page_topic:edit_validate", %{
      "page_topic_edit" => %{"relevancy_level" => "9"}
    })

    assert modal_has_element?(view, "#page-topic-inline-edit-relevancy[value=\"9\"]")

    render_hook(view, "page_topic:edit_submit", %{
      "page_topic_edit" => %{"relevancy_level" => "9"}
    })

    assert modal_has_element?(view, testid("page-topic-modal-index"))

    assert {:ok, updated_taggings} = Tags.list_taggings(page, scope: owner_scope)
    updated_owner_tagging = Enum.find(updated_taggings, &(&1.id == owner_tagging.id))
    assert updated_owner_tagging.dimensions == %{"relevancy" => 9}

    render_hook(view, "page_topic:edit_start", %{"tagging_id" => owner_tagging.id})
    render_hook(view, "page_topic:edit_remove", %{})

    assert modal_has_element?(view, testid("page-topic-modal-index"))
    assert {:ok, [remaining_tagging]} = Tags.list_taggings(page, scope: owner_scope)
    assert remaining_tagging.id == member_tagging.id
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

  defp modal_has_element?(view, selector) do
    [{"template", _attributes, portal_content}] =
      view
      |> element("#page-topic-inline-modal_portal")
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.to_tree()

    portal_content
    |> LazyHTML.from_tree()
    |> LazyHTML.query(selector)
    |> Enum.any?()
  end

  defp scope(actor, tenant), do: %Scope{actor: actor, tenant: tenant}
end
