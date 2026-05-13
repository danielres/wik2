defmodule Wik.Accounts.GroupSlugTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Accounts.Group

  test "allows duplicate names with different slugs" do
    actor = generate(user(role: :superadmin))

    assert {:ok, _group} =
             Ash.create(
               Group,
               %{name: "Wik Group", slug: "wik-group", description: "First"},
               action: :create,
               actor: actor
             )

    assert {:ok, second_group} =
             Ash.create(
               Group,
               %{name: "Wik Group", slug: "wik-group-2", description: "Second"},
               action: :create,
               actor: actor
             )

    assert second_group.name == "Wik Group"
    assert second_group.slug == "wik-group-2"
  end

  test "rejects duplicate slugs" do
    actor = generate(user(role: :superadmin))

    assert {:ok, _group} =
             Ash.create(
               Group,
               %{name: "First Group", slug: "same-group"},
               action: :create,
               actor: actor
             )

    assert {:error, error} =
             Ash.create(
               Group,
               %{name: "Second Group", slug: "same-group"},
               action: :create,
               actor: actor
             )

    assert Exception.message(error) =~ "slug"
  end
end
