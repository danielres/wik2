defmodule Wik.Library.ProvisioningTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Library.EntryType
  alias Wik.Library.Field
  alias Wik.Library.Provisioning
  alias Wik.Scope

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
end
