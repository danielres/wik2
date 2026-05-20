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

  test "tag page shows tagged members ordered by interest, then skill, then username", %{
    conn: conn
  } do
    owner = generate(user())
    first_user = generate(user())
    second_user = generate(user())
    third_user = generate(user())
    group = generate(group(author: owner))
    add_membership(group, owner, :owner)

    first_membership =
      group
      |> add_membership(first_user, :member)
      |> then(&set_username(&1, "ada"))
      |> reload_membership()

    second_membership =
      group
      |> add_membership(second_user, :member)
      |> then(&set_username(&1, "bea"))
      |> reload_membership()

    third_membership =
      group
      |> add_membership(third_user, :member)
      |> then(&set_username(&1, "cy"))
      |> reload_membership()

    grant_active_telegram_access(group, owner)
    grant_active_telegram_access(group, first_user)
    grant_active_telegram_access(group, second_user)
    grant_active_telegram_access(group, third_user)

    owner_scope = scope(owner, group)
    first_scope = scope(first_user, group)
    second_scope = scope(second_user, group)
    third_scope = scope(third_user, group)

    {:ok, tag} = Tags.create_tag("fusion", "Fusion", "Late-night socials", scope: owner_scope)

    {:ok, first_tagging} =
      Tags.upsert_membership_tagging(
        first_membership,
        tag.id,
        %{dimensions: %{"interest" => 9, "skill" => 2}, description: "Hosts practice nights"},
        scope: first_scope
      )

    {:ok, second_tagging} =
      Tags.upsert_membership_tagging(
        second_membership,
        tag.id,
        %{dimensions: %{"interest" => 7, "skill" => 2}, description: "Weekend regular"},
        scope: second_scope
      )

    {:ok, third_tagging} =
      Tags.upsert_membership_tagging(
        third_membership,
        tag.id,
        %{dimensions: %{"interest" => 4, "skill" => 6}, description: nil},
        scope: third_scope
      )

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{group.slug}/tags/#{tag.slug}")

    assert has_element?(view, testid("tag-page"))
    assert has_element?(view, testid("tag-member-taggings-table"))
    assert has_element?(view, testid("tag-member-tagging-member-#{first_tagging.id}"))
    assert has_element?(view, testid("tag-member-tagging-member-#{second_tagging.id}"))
    assert has_element?(view, testid("tag-member-tagging-member-#{third_tagging.id}"))
    assert has_element?(view, testid("tag-member-tagging-interest-#{first_tagging.id}"))
    assert has_element?(view, testid("tag-member-tagging-skill-#{third_tagging.id}"))
    assert has_element?(view, testid("tag-member-tagging-description-#{first_tagging.id}"))

    html = render(view)

    assert index_of_testid(html, "tag-member-tagging-member-#{first_tagging.id}") <
             index_of_testid(html, "tag-member-tagging-member-#{second_tagging.id}")

    assert index_of_testid(html, "tag-member-tagging-member-#{second_tagging.id}") <
             index_of_testid(html, "tag-member-tagging-member-#{third_tagging.id}")

    render_click(element(view, testid("tag-member-tagging-open-#{first_tagging.id}")))

    assert_redirect(
      view,
      ~p"/#{group.slug}/wiki/members/#{first_membership.username}/tag/#{tag.slug}"
    )
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

  defp set_username(membership, username) do
    Ash.update!(
      membership,
      %{username: username},
      action: :set_username,
      authorize?: false,
      domain: Wik.Accounts
    )
  end

  defp reload_membership(membership) do
    membership.group_id
    |> Wik.Accounts.get_membership(membership.user_id)
    |> elem(1)
  end

  defp index_of_testid(html, testid) do
    case :binary.match(html, ~s(data-testid="#{testid}")) do
      {index, _length} -> index
      :nomatch -> nil
    end
  end

  defp scope(actor, tenant), do: %Scope{actor: actor, tenant: tenant}
end
