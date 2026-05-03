defmodule Wik.Blocks.BlockTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Blocks.Block
  alias Wik.Scope

  describe "owner validations" do
    test "fails when no owner is set" do
      actor = generate(user())

      assert {:error, _error} =
               Ash.create(
                 Block,
                 %{
                   data: %{"text" => "Hello"},
                   type: :text
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end

    test "fails when both owners are set" do
      actor = generate(user())
      group = generate(group())

      assert {:error, _error} =
               Ash.create(
                 Block,
                 %{
                   data: %{"text" => "Hello"},
                   owner_group_id: group.id,
                   owner_user_id: actor.id,
                   type: :text
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end
  end

  defp scope(actor, tenant \\ nil) do
    %Scope{actor: actor, tenant: tenant}
  end
end
