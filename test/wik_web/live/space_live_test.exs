defmodule WikWeb.SpaceLiveTest do
  use WikWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Wik.TestGenerators

  alias AshAuthentication.Jwt
  alias AshAuthentication.Plug.Helpers, as: AuthHelpers
  alias Wik.Accounts.Membership
  alias Wik.Blocks
  alias Wik.Blocks.Block

  require Ash.Query

  test "owner can delete orphan space-owned blocks", %{conn: conn} do
    owner = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    scope = scope(owner, space)

    {:ok, block} =
      Blocks.create_space_owned_block(
        space,
        %{data: %{"text" => "Orphan"}, type: :markdown},
        scope: scope
      )

    {:ok, view, _html} =
      conn
      |> log_in(owner)
      |> live(~p"/#{space.slug}/orphans")

    assert has_element?(view, testid("orphan-block-#{block.id}-destroy"))

    view
    |> element(testid("orphan-block-#{block.id}-destroy"))
    |> render_click()

    refute has_element?(view, testid("orphan-block-#{block.id}-destroy"))
    assert {:error, error} = Ash.get(Block, block.id, scope: scope)
    assert [%Ash.Error.Query.NotFound{}] = error.errors
  end

  defp scope(actor, tenant), do: %Wik.Scope{actor: actor, tenant: tenant}

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
