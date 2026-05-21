defmodule Wik.Accounts.SpaceSlugTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

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
end
