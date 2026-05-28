defmodule WikWeb.MemberProfileLiveTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Access.ExternalIdentity
  alias Wik.Access.Grant
  alias Wik.Access.Source
  alias Wik.Accounts.Membership
  alias Wik.Scope
  alias Wik.Tags

  test "membership owner can add, update, and remove their own taggings from the profile page",
       %{conn: conn} do
    %{space: space, membership: membership, owner: owner, user: user} = member_fixture()
    owner_scope = scope(owner, space)
    member_scope = scope(user, space)

    {:ok, dance} = Tags.create_tag("dance", "Dance", nil, scope: owner_scope)

    {:ok, view, _html} =
      conn
      |> log_in(user)
      |> live(~p"/#{space.slug}/wiki/members/#{membership.username}")

    render_async(view)

    assert has_element?(view, testid("member-profile-page"))
    assert has_element?(view, testid("member-tagging-add"))

    render_click(element(view, testid("member-tagging-add")))

    render_submit(
      form(view, testid("member-tagging-form-form"),
        form: %{
          "description" => "Loves partnerwork",
          "tag_id" => dance.id,
          "interest_level" => "5",
          "skill_level" => "0"
        }
      )
    )

    render_async(view)

    assert {:ok, taggings} = Tags.list_membership_taggings(membership, scope: member_scope)

    assert Enum.map(taggings, &{&1.dimensions, &1.description}) == [
             {%{"interest" => 5}, "Loves partnerwork"}
           ]

    assert has_element?(view, testid("member-tagging-row-#{dance.id}"))
    assert has_element?(view, testid("member-tagging-description-#{dance.id}"))
    assert has_element?(view, testid("member-tagging-interest-#{dance.id}"))
    refute has_element?(view, testid("member-tagging-skill-#{dance.id}"))

    render_click(element(view, testid("member-tagging-open-#{dance.id}")))
    assert_patch(view, ~p"/#{space.slug}/wiki/members/#{membership.username}/tag/#{dance.slug}")
    assert has_element?(view, testid("member-tagging-details"))
    assert has_element?(view, testid("member-tagging-edit-#{dance.id}"))

    render_click(element(view, testid("member-tagging-edit-#{dance.id}")))

    render_submit(
      form(view, testid("member-tagging-form-form"),
        form: %{
          "description" => "Teaches occasionally",
          "tag_id" => dance.id,
          "interest_level" => "0",
          "skill_level" => "4"
        }
      )
    )

    render_async(view)

    assert {:ok, taggings} = Tags.list_membership_taggings(membership, scope: member_scope)

    assert Enum.map(taggings, &{&1.dimensions, &1.description}) == [
             {%{"skill" => 4}, "Teaches occasionally"}
           ]

    refute has_element?(view, testid("member-tagging-interest-#{dance.id}"))
    assert has_element?(view, testid("member-tagging-skill-#{dance.id}"))
    assert has_element?(view, testid("member-tagging-description-#{dance.id}"))

    render_click(element(view, testid("member-tagging-open-#{dance.id}")))
    assert_patch(view, ~p"/#{space.slug}/wiki/members/#{membership.username}/tag/#{dance.slug}")
    assert has_element?(view, testid("member-tagging-details"))

    render_click(element(view, testid("member-tagging-edit-#{dance.id}")))
    assert has_element?(view, testid("member-tagging-delete"))

    render_click(element(view, testid("member-tagging-delete")))

    render_async(view)

    assert {:ok, []} = Tags.list_membership_taggings(membership, scope: member_scope)
    assert has_element?(view, testid("member-tagging-empty"))
    assert_patch(view, ~p"/#{space.slug}/wiki/members/#{membership.username}")
  end

  test "other space members can read but not edit another member's taggings", %{conn: conn} do
    %{space: space, membership: membership, other_user: other_user, owner: owner, user: user} =
      member_fixture(other_member?: true)

    owner_scope = scope(owner, space)
    member_scope = scope(user, space)

    {:ok, dance} = Tags.create_tag("dance", "Dance", nil, scope: owner_scope)

    assert {:ok, _} =
             Tags.upsert_membership_tagging(
               membership,
               dance.id,
               %{
                 dimensions: %{"interest" => 4, "skill" => 1},
                 description: "Steady social dancer"
               },
               scope: member_scope
             )

    {:ok, view, _html} =
      conn
      |> log_in(other_user)
      |> live(~p"/#{space.slug}/wiki/members/#{membership.username}")

    render_async(view)

    assert has_element?(view, testid("member-profile-page"))
    refute has_element?(view, testid("member-tagging-add"))

    assert has_element?(view, testid("member-tagging-row-#{dance.id}"))
    assert has_element?(view, testid("member-tagging-interest-#{dance.id}"))
    assert has_element?(view, testid("member-tagging-skill-#{dance.id}"))
    refute has_element?(view, testid("member-tagging-delete"))

    render_click(element(view, testid("member-tagging-open-#{dance.id}")))

    assert_patch(view, ~p"/#{space.slug}/wiki/members/#{membership.username}/tag/#{dance.slug}")
    assert has_element?(view, testid("member-tagging-details"))
    refute has_element?(view, testid("member-tagging-edit-#{dance.id}"))
  end

  test "superadmin can add taggings to another member from the profile page", %{conn: conn} do
    %{space: space, membership: membership, owner: owner} = member_fixture()
    superadmin = generate(user(role: :superadmin))
    owner_scope = scope(owner, space)
    superadmin_scope = scope(superadmin, space)

    {:ok, dance} = Tags.create_tag("dance", "Dance", nil, scope: owner_scope)

    {:ok, view, _html} =
      conn
      |> log_in(superadmin)
      |> live(~p"/#{space.slug}/wiki/members/#{membership.username}")

    render_async(view)

    assert has_element?(view, testid("member-tagging-add"))

    render_click(element(view, testid("member-tagging-add")))

    render_submit(
      form(view, testid("member-tagging-form-form"),
        form: %{
          "description" => "Observed by superadmin",
          "tag_id" => dance.id,
          "interest_level" => "4",
          "skill_level" => "0"
        }
      )
    )

    render_async(view)

    assert {:ok, taggings} = Tags.list_membership_taggings(membership, scope: superadmin_scope)

    assert Enum.map(taggings, &{&1.dimensions, &1.description}) == [
             {%{"interest" => 4}, "Observed by superadmin"}
           ]
  end

  test "member profile shows space access grants with issuer details and hides other-space grants",
       %{conn: conn} do
    owner = generate(user())
    user = generate(user())
    space = generate(space(author: owner))
    other_space = generate(space(author: owner))

    owner_membership = add_membership(space, owner, :owner)
    set_username(owner_membership, "owner-issuer")

    membership =
      space
      |> add_membership(user, :member)
      |> then(&set_username(&1, "ada"))
      |> reload_membership()

    other_owner_membership = add_membership(other_space, owner, :owner)
    set_username(other_owner_membership, "owner-elsewhere")
    add_membership(other_space, user, :member)

    %{grant: visible_grant} =
      create_telegram_access_grant(space, user, owner, "channel", "ada_here")

    %{grant: hidden_grant} =
      create_telegram_access_grant(other_space, user, owner, "group", "ada_elsewhere")

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/wiki/members/#{membership.username}")

    render_async(view)

    assert has_element?(view, testid("member-access-grants"))
    assert has_element?(view, testid("access-grant-#{visible_grant.id}"))
    refute has_element?(view, testid("access-grant-#{hidden_grant.id}"))
    assert has_element?(view, testid("access-grant-via-#{visible_grant.id}"))
    assert has_element?(view, testid("access-grant-source-title-#{visible_grant.id}"))
    assert has_element?(view, testid("access-grant-issuer-#{visible_grant.id}"))
    assert has_element?(view, testid("access-grant-identity-#{visible_grant.id}"))
    assert has_element?(view, testid("access-grant-status-#{visible_grant.id}"))
    refute has_element?(view, testid("access-grant-identity-#{hidden_grant.id}"))
  end

  test "member profile shows an empty access state when the member has no grants in this space",
       %{conn: conn} do
    owner = generate(user())
    user = generate(user())
    space = generate(space(author: owner))

    add_membership(space, owner, :owner)

    membership =
      space
      |> add_membership(user, :member)
      |> then(&set_username(&1, "ada"))
      |> reload_membership()

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/wiki/members/#{membership.username}")

    render_async(view)

    assert has_element?(view, testid("member-access-empty"))
  end

  test "member profile table orders rows by highest interest first and shows blank missing sides",
       %{conn: conn} do
    %{space: space, membership: membership, owner: owner, user: user} = member_fixture()
    owner_scope = scope(owner, space)
    member_scope = scope(user, space)

    {:ok, dance} = Tags.create_tag("dance", "Dance", nil, scope: owner_scope)
    {:ok, acro} = Tags.create_tag("acro", "Acro", nil, scope: owner_scope)
    {:ok, tango} = Tags.create_tag("tango", "Tango", nil, scope: owner_scope)

    assert {:ok, _} =
             Tags.upsert_membership_tagging(
               membership,
               tango.id,
               %{dimensions: %{"interest" => 4, "skill" => 5}, description: nil},
               scope: member_scope
             )

    assert {:ok, _} =
             Tags.upsert_membership_tagging(
               membership,
               dance.id,
               %{dimensions: %{"interest" => 2, "skill" => 3}, description: nil},
               scope: member_scope
             )

    assert {:ok, _} =
             Tags.upsert_membership_tagging(
               membership,
               acro.id,
               %{dimensions: %{"interest" => 2, "skill" => 1}, description: nil},
               scope: member_scope
             )

    {:ok, view, _html} =
      conn
      |> log_in(user)
      |> live(~p"/#{space.slug}/wiki/members/#{membership.username}")

    render_async(view)

    assert has_element?(view, testid("member-tagging-row-#{tango.id}"))
    assert has_element?(view, testid("member-tagging-interest-#{tango.id}"))
    assert has_element?(view, testid("member-tagging-skill-#{tango.id}"))
    assert has_element?(view, testid("member-tagging-name-#{tango.id}"))
    assert has_element?(view, testid("member-tagging-name-#{acro.id}"))
    assert has_element?(view, testid("member-tagging-name-#{dance.id}"))
    assert has_element?(view, testid("member-tagging-interest-#{dance.id}"))
    assert has_element?(view, testid("member-tagging-skill-#{dance.id}"))

    html = render(view)

    assert index_of_testid(html, "member-tagging-name-#{tango.id}") <
             index_of_testid(html, "member-tagging-name-#{acro.id}")
  end

  test "tag route opens the tagging modal in read mode", %{conn: conn} do
    %{space: space, membership: membership, owner: owner, user: user} = member_fixture()
    owner_scope = scope(owner, space)
    member_scope = scope(user, space)

    {:ok, dance} = Tags.create_tag("dance", "Dance", nil, scope: owner_scope)

    assert {:ok, _} =
             Tags.upsert_membership_tagging(
               membership,
               dance.id,
               %{dimensions: %{"interest" => 7}, description: "Late-night social regular"},
               scope: member_scope
             )

    {:ok, view, _html} =
      conn
      |> log_in(user)
      |> live(~p"/#{space.slug}/wiki/members/#{membership.username}/tag/#{dance.slug}")

    render_async(view)

    assert has_element?(view, testid("member-tagging-details"))
    assert has_element?(view, testid("member-tagging-edit-#{dance.id}"))
    assert has_element?(view, testid("member-tagging-interest-#{dance.id}"))
    assert has_element?(view, testid("member-tagging-details-description"))
    refute has_element?(view, testid("member-tagging-form-form"))
  end

  defp member_fixture(opts \\ []) do
    owner = generate(user())
    user = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    membership = add_membership(space, user, :member)
    grant_active_telegram_access(space, user)
    set_username(membership, "ada")

    fixture = %{space: space, membership: reload_membership(membership), owner: owner, user: user}

    if Keyword.get(opts, :other_member?, false) do
      other_user = generate(user())
      other_membership = add_membership(space, other_user, :member)
      grant_active_telegram_access(space, other_user)
      set_username(other_membership, "bob")
      Map.put(fixture, :other_user, other_user)
    else
      fixture
    end
  end

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
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
    membership.space_id
    |> Wik.Accounts.get_membership(membership.user_id)
    |> elem(1)
  end

  defp log_in(conn, user) do
    {:ok, token, _claims} = Jwt.token_for_user(user)
    user = Ash.Resource.set_metadata(user, %{token: token})

    conn
    |> init_test_session(%{})
    |> AuthHelpers.store_in_session(user)
  end

  defp index_of_testid(html, testid) do
    case :binary.match(html, ~s(data-testid="#{testid}")) do
      {index, _length} -> index
      :nomatch -> nil
    end
  end

  defp scope(actor, tenant), do: %Scope{actor: actor, tenant: tenant}

  defp create_telegram_access_grant(space, user, issuer, chat_type, username) do
    source =
      Ash.create!(
        Source,
        %{
          claimed_at: DateTime.utc_now(),
          claimed_by_user_id: issuer.id,
          metadata: %{"chat" => %{"type" => chat_type}},
          space_id: space.id,
          provider: :telegram,
          provider_source_id: "telegram-source-#{System.unique_integer([:positive])}",
          status: :active,
          title: "Telegram #{String.capitalize(chat_type)}"
        },
        authorize?: false,
        domain: Wik.Access
      )

    identity =
      Ash.create!(
        ExternalIdentity,
        %{
          avatar_url: "https://telegram.example/avatar.png",
          display_name: "Ada Lovelace",
          provider: :telegram,
          provider_user_id: "telegram-user-#{System.unique_integer([:positive])}",
          user_id: user.id,
          username: username
        },
        authorize?: false,
        domain: Wik.Access
      )

    grant =
      Ash.create!(
        Grant,
        %{
          external_identity_id: identity.id,
          last_verified_at: DateTime.utc_now(),
          source_id: source.id,
          status: :active,
          user_id: user.id
        },
        authorize?: false,
        domain: Wik.Access
      )

    %{grant: grant, identity: identity, source: source}
  end
end
