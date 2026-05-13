defmodule WikWeb.TenantContextTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias WikWeb.TenantContext
  alias Wik.Accounts.GroupUserRelation

  test "build loads the current membership avatar url from access grants" do
    user = generate(user())
    group = generate(group())
    add_membership(group, user, :member)
    %{identity: identity} = grant_active_telegram_access(group, user)

    assert {:ok, _identity} =
             Ash.update(
               identity,
               %{avatar_url: "https://telegram.example/avatar.png"},
               action: :update,
               authorize?: false,
               domain: Wik.Access
             )

    tenant_context = TenantContext.build(user, group)

    assert tenant_context.current_membership.avatar_url == "https://telegram.example/avatar.png"
  end

  test "build returns nil username form when membership username is already set" do
    user = generate(user())
    group = generate(group())
    membership = add_membership(group, user, :member)

    assert {:ok, _membership} =
             Ash.update(
               membership,
               %{username: "alice"},
               action: :set_username,
               scope: %Wik.Scope{actor: user, tenant: group}
             )

    tenant_context = TenantContext.build(user, group)

    assert tenant_context.current_membership.username == "alice"
    assert tenant_context.membership_username_form == nil
  end

  test "build pre-fills the username form from the best available external identity username" do
    user = generate(user())
    group = generate(group())
    add_membership(group, user, :member)
    %{identity: identity} = grant_active_telegram_access(group, user)

    assert {:ok, _identity} =
             Ash.update(
               identity,
               %{username: "@Telegram_User"},
               action: :update,
               authorize?: false,
               domain: Wik.Access
             )

    tenant_context = TenantContext.build(user, group)

    assert tenant_context.current_membership.user_id == user.id
    assert tenant_context.membership_username_form[:username].value == "telegram-user"
  end

  test "build returns nil form when the actor has no membership in the group" do
    user = generate(user())
    group = generate(group())

    tenant_context = TenantContext.build(user, group)

    assert tenant_context.current_membership == nil
    assert tenant_context.membership_username_form == nil
  end

  defp add_membership(group, user, type) do
    Ash.create!(
      GroupUserRelation,
      %{group_id: group.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
  end
end
