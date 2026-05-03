defmodule Wik.Wiki.PageTree.TreeOps.ValidateUniqueSiblingSlugsTest do
  use ExUnit.Case, async: true

  alias Wik.Wiki.PageTree.TreeOps.ValidateUniqueSiblingSlugs

  test "allows the same slug under different parents" do
    nodes = [
      %{id: 1, parent_id: nil, slug: "home"},
      %{id: 2, parent_id: 1, slug: "about"},
      %{id: 3, parent_id: nil, slug: "docs"},
      %{id: 4, parent_id: 3, slug: "about"}
    ]

    assert :ok = ValidateUniqueSiblingSlugs.call(nodes)
  end

  test "rejects duplicate root slugs" do
    nodes = [
      %{id: 1, parent_id: nil, slug: "home"},
      %{id: 2, parent_id: nil, slug: "home"}
    ]

    assert {
             :error,
             :duplicate_sibling_slug,
             %{parent_id: nil, slug: "home"}
           } =
             ValidateUniqueSiblingSlugs.call(nodes)
  end

  test "rejects duplicate sibling slugs under the same parent" do
    nodes = [
      %{id: 1, parent_id: nil, slug: "home"},
      %{id: 2, parent_id: 1, slug: "about"},
      %{id: 3, parent_id: 1, slug: "about"}
    ]

    assert {
             :error,
             :duplicate_sibling_slug,
             %{parent_id: 1, slug: "about"}
           } =
             ValidateUniqueSiblingSlugs.call(nodes)
  end
end
