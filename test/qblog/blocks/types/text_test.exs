defmodule Qblog.Blocks.Types.TextTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Blocks.Block
  alias Qblog.Scope

  describe "validate_data/1" do
    test "allows blank text block data on create" do
      actor = generate(user())

      assert {:ok, _block} =
               Ash.create(
                 Block,
                 %{
                   data: %{"text" => " "},
                   owner_user_id: actor.id,
                   type: :text
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end

    test "fails when text block text is not a string" do
      actor = generate(user())

      assert {:error, _error} =
               Ash.create(
                 Block,
                 %{
                   data: %{"text" => 123},
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
