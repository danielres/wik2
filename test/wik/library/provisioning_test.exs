defmodule Wik.Library.ProvisioningTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Library.EntryType
  alias Wik.Library.Field
  alias Wik.Library.Provisioning
  alias Wik.Library.Settings
  alias Wik.Scope
  alias WikWeb.LibraryLive.State
  alias WikWeb.LibraryLive.Schema

  test "rolls back the type and preceding fields when field creation fails" do
    actor = generate(user())
    space = generate(space(author: actor))
    scope = %Scope{actor: actor, tenant: space}

    template = %{
      description: "A type that must not be partially provisioned.",
      fields: [
        %{key: "name", label: "Name", options: [], required?: true, type: :title},
        %{key: "invalid", label: "Invalid", options: [], required?: false, type: :invalid}
      ],
      id: "broken-type",
      name: "Broken type"
    }

    assert {:error, _error} = Provisioning.create_type(template, scope)

    assert [] = Ash.read!(EntryType, authorize?: false, tenant: space.id)
    assert [] = Ash.read!(Field, authorize?: false, tenant: space.id)
  end

  test "ensuring default types is idempotent" do
    actor = generate(user())
    space = generate(space(author: actor))
    scope = %Scope{actor: actor, tenant: space}

    assert :ok = Provisioning.ensure_default_types(scope)
    assert :ok = Provisioning.ensure_default_types(scope)

    expected_slugs =
      Schema.built_in_templates()
      |> Enum.reject(&(&1.id == "custom"))
      |> Enum.map(& &1.id)
      |> Enum.sort()

    assert {:ok, types} = Wik.Library.list_entry_types(scope: scope)
    assert Enum.map(types, & &1.slug) |> Enum.sort() == expected_slugs
  end

  test "snapshot reuses the existing settings row" do
    actor = generate(user())
    space = generate(space(author: actor))
    scope = %Scope{actor: actor, tenant: space}

    settings =
      Ash.create!(Settings, %{automatic_topic_matching: false},
        action: :create,
        actor: actor,
        authorize?: false,
        tenant: space
      )

    snapshot = Wik.Library.snapshot(scope)

    assert snapshot.automatic_topic_matching? == false
    assert [stored_settings] = Ash.read!(Settings, authorize?: false, tenant: space.id)
    assert stored_settings.id == settings.id
  end

  test "ignores moving the first persisted field upward" do
    actor = generate(user())
    space = generate(space(author: actor))
    scope = %Scope{actor: actor, tenant: space}
    state = State.new(scope)
    type = State.find_type(state, "external-media")
    first_field = List.first(type.fields)

    assert {:ok, _state, moved_type} = State.move_field(state, type.id, first_field.id, :up)
    assert Enum.map(moved_type.fields, & &1.id) == Enum.map(type.fields, & &1.id)
  end
end
