defmodule Qblog.Blocks.Types.MarkdownTest do
  use Qblog.DataCase, async: true

  import Qblog.TestGenerators

  alias Qblog.Blocks
  alias Qblog.Blocks.Block
  alias Qblog.Scope

  describe "validate_data/1" do
    test "allows blank markdown block data on create" do
      actor = generate(user())

      assert {:ok, _block} =
               Ash.create(
                 Block,
                 %{
                   data: %{"text" => " "},
                   owner_user_id: actor.id,
                   type: :markdown
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end

    test "fails when markdown block text is not a string" do
      actor = generate(user())

      assert {:error, _error} =
               Ash.create(
                 Block,
                 %{
                   data: %{"text" => 123},
                   owner_user_id: actor.id,
                   type: :markdown
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end
  end

  describe "update_block/3" do
    test "normalizes the submitted markdown text" do
      actor = generate(user())
      scope = scope(actor)

      {:ok, block} =
        Blocks.create_user_owned_block(
          %{type: :markdown},
          scope: scope
        )

      assert {:ok, updated_block} =
               Blocks.update_block(
                 block,
                 %{
                   "text" =>
                     "\r\n\r\n## Title  \r\n\r\n\r\n\r\nBody  \r\n\r\n\r\n- Item  \r\n\r\n"
                 },
                 scope: scope
               )

      assert updated_block.data == %{"text" => "## Title\n\nBody\n\n- Item"}
    end
  end

  defp scope(actor, tenant \\ nil) do
    %Scope{actor: actor, tenant: tenant}
  end
end
