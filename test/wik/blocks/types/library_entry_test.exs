defmodule Wik.Blocks.Types.LibraryEntryTest do
  use ExUnit.Case, async: true

  alias Wik.Blocks.Types.LibraryEntry

  describe "validate_data/1" do
    test "accepts empty block data" do
      assert :ok = LibraryEntry.validate_data(%{})
    end

    test "rejects non-empty block data" do
      assert {:error, field: :data, message: "library entry blocks use a reference"} =
               LibraryEntry.validate_data(%{"entry_id" => "stored-in-the-reference"})
    end
  end
end
