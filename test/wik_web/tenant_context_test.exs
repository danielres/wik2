defmodule WikWeb.TenantContextTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias WikWeb.TenantContext
  alias Wik.Accounts.Membership

  test "build loads the current membership avatar url from access grants" do
    user = generate(user())
    space = generate(space())
    add_membership(space, user, :member)
    %{identity: identity} = grant_active_telegram_access(space, user)

    assert {:ok, _identity} =
             Ash.update(
               identity,
               %{avatar_url: "https://telegram.example/avatar.png"},
               action: :update,
               authorize?: false,
               domain: Wik.Access
             )

    tenant_context = TenantContext.build(user, space)

    assert tenant_context.current_membership.avatar_url == "https://telegram.example/avatar.png"
  end

  test "build returns nil username form when membership username is already set" do
    user = generate(user())
    space = generate(space())
    membership = add_membership(space, user, :member)

    assert {:ok, _membership} =
             Ash.update(
               membership,
               %{username: "alice"},
               action: :set_username,
               scope: %Wik.Scope{actor: user, tenant: space}
             )

    tenant_context = TenantContext.build(user, space)

    assert tenant_context.current_membership.username == "alice"
    assert tenant_context.membership_username_form == nil
  end

  test "build pre-fills the username form from the best available external identity username" do
    user = generate(user())
    space = generate(space())
    add_membership(space, user, :member)
    %{identity: identity} = grant_active_telegram_access(space, user)

    assert {:ok, _identity} =
             Ash.update(
               identity,
               %{username: "@Telegram_User"},
               action: :update,
               authorize?: false,
               domain: Wik.Access
             )

    tenant_context = TenantContext.build(user, space)

    assert tenant_context.current_membership.user_id == user.id
    assert tenant_context.membership_username_form[:username].value == "telegram-user"
  end

  test "build returns nil form when the actor has no membership in the space" do
    user = generate(user())
    space = generate(space())

    tenant_context = TenantContext.build(user, space)

    assert tenant_context.current_membership == nil
    assert tenant_context.membership_username_form == nil
  end

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
  end
end
