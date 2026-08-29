defmodule Wik.UpdatesTest do
  use ExUnit.Case, async: true

  alias Wik.Updates
  alias Wik.Updates.Update

  @moduletag :tmp_dir

  test "loads valid updates newest first", %{tmp_dir: tmp_dir} do
    write_update(tmp_dir, 20, "2026-01-01", "improvements")
    write_update(tmp_dir, 21, "2026-01-01", "bug_fixes")
    write_update(tmp_dir, 19, "2025-12-31", "new_features")

    assert {:ok,
            [
              %Update{pr_number: 21, sections: [%{category: "bug_fixes"}]},
              %Update{pr_number: 20, sections: [%{category: "improvements"}]},
              %Update{pr_number: 19, sections: [%{category: "new_features"}]}
            ]} = Updates.list_updates(tmp_dir)
  end

  test "returns an error for malformed JSON", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "19.json")
    File.write!(path, "{")

    assert {:error, {:invalid_update, ^path, {:invalid_json, _message}}} =
             Updates.list_updates(tmp_dir)
  end

  test "returns an error for an unsupported category", %{tmp_dir: tmp_dir} do
    path = write_update(tmp_dir, 19, "2026-05-18", "internal_refactors")

    assert {:error, {:invalid_update, ^path, {:invalid_category, "internal_refactors"}}} =
             Updates.list_updates(tmp_dir)
  end

  test "returns an error for a non-canonical PR filename", %{tmp_dir: tmp_dir} do
    path = write_update(tmp_dir, 19, "2026-05-18", "improvements", filename: "019.json")

    assert {:error, {:invalid_update, ^path, :invalid_filename}} =
             Updates.list_updates(tmp_dir)
  end

  test "returns an error for empty section items", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "19.json")

    write_json(path, %{
      "merged_on" => "2026-05-18",
      "sections" => [
        %{"category" => "improvements", "items" => []}
      ]
    })

    assert {:error, {:invalid_update, ^path, :invalid_items}} =
             Updates.list_updates(tmp_dir)
  end

  defp write_update(directory, pr_number, merged_on, category, opts \\ []) do
    filename = Keyword.get(opts, :filename, "#{pr_number}.json")
    path = Path.join(directory, filename)

    write_json(path, %{
      "merged_on" => merged_on,
      "source" => "generated",
      "sections" => [
        %{"category" => category, "items" => ["A concise user-facing change"]}
      ]
    })

    path
  end

  defp write_json(path, data) do
    File.write!(path, Jason.encode!(data))
  end
end
