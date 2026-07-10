defmodule Wik.Accounts.SpaceSlugTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts
  alias Wik.Accounts.Space

  test "allows duplicate names with different slugs" do
    actor = generate(user(role: :superadmin))

    assert {:ok, _space} =
             Ash.create(
               Space,
               %{name: "Wik Space", slug: "wik-space", description: "First"},
               action: :create,
               actor: actor
             )

    assert {:ok, second_space} =
             Ash.create(
               Space,
               %{name: "Wik Space", slug: "wik-space-2", description: "Second"},
               action: :create,
               actor: actor
             )

    assert second_space.name == "Wik Space"
    assert second_space.slug == "wik-space-2"
  end

  test "rejects duplicate slugs" do
    actor = generate(user(role: :superadmin))

    assert {:ok, _space} =
             Ash.create(
               Space,
               %{name: "First Space", slug: "same-space"},
               action: :create,
               actor: actor
             )

    assert {:error, error} =
             Ash.create(
               Space,
               %{name: "Second Space", slug: "same-space"},
               action: :create,
               actor: actor
             )

    assert Exception.message(error) =~ "slug"
  end

  test "space_slug_to_id resolves a 16-character slug as a slug" do
    space = generate(space(slug: "damn-interesting"))

    assert Accounts.space_slug_to_id("damn-interesting") == space.id
  end

  test "tenant_to_space_id resolves supported tenant shapes" do
    space = generate(space(slug: "tenant-fixture"))

    assert Accounts.tenant_to_space_id(space) == space.id
    assert Accounts.tenant_to_space_id(space.id) == space.id
    assert Accounts.tenant_to_space_id(space.slug) == space.id
  end
end
