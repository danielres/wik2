defmodule WikWeb.TagLiveTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Accounts.GroupUserRelation
  alias Wik.Scope
  alias Wik.Tags

  test "tag page defaults to view mode and can be edited", %{conn: conn} do
    owner = generate(user())
    group = generate(group(author: owner))
    add_membership(group, owner, :owner)
    scope = scope(owner, group)

    {:ok, tag} = Tags.create_tag("alpha", "Alpha", "Foundational rhythm", scope: scope)

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{group.slug}/tags/#{tag.slug}")

    assert has_element?(view, testid("tag-page"))
    assert has_element?(view, testid("tag-edit-mode-toggle"))
    assert has_element?(view, testid("tag-page-description"))
    refute has_element?(view, testid("tag-form-form"))

    render_click(element(view, testid("tag-edit-mode-toggle")))

    assert has_element?(view, testid("tag-edit-mode-ok"))
    assert has_element?(view, testid("tag-form-form"))

    render_submit(
      form(view, testid("tag-form-form"),
        form: %{"name" => "Social dance", "description" => "Updated description"}
      )
    )

    assert_patch(view, ~p"/#{group.slug}/tags/social-dance")
    assert has_element?(view, testid("tag-page"))
    refute has_element?(view, testid("tag-form-form"))

    assert {:ok, updated_tag} = Tags.get_tag_by_slug("social-dance", scope: scope)
    assert updated_tag.description == "Updated description"
  end

  defp add_membership(group, user, type) do
    Ash.create!(
      GroupUserRelation,
      %{group_id: group.id, type: type, user_id: user.id},
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
