defmodule Wik.Wiki.PageTree.TreeOpsTest do
  use ExUnit.Case, async: true

  alias Wik.Wiki.PageTree.TreeOps.CreateNodeAtPath

  test "CreateNodeAtPath.call creates all missing nodes for a slash path" do
    nodes = [
      %{id: 1, page_id: nil, parent_id: nil, slug: "docs", title: "Docs"}
    ]

    assert {:ok, %{id: 3, parent_id: 2, slug: "install", title: "Install", page_id: "page-1"},
            nodes} =
             CreateNodeAtPath.call(nodes, "docs/guides/install", %{
               title: "Install",
               page_id: "page-1"
             })

    assert [
             %{id: 1, parent_id: nil, slug: "docs", title: "Docs", page_id: nil},
             %{id: 2, parent_id: 1, slug: "guides", title: "Guides", page_id: nil},
             %{id: 3, parent_id: 2, slug: "install", title: "Install", page_id: "page-1"}
           ] = nodes
  end

  test "CreateNodeAtPath.call accepts a list path and reuses existing segments" do
    nodes = [
      %{id: 1, page_id: nil, parent_id: nil, slug: "docs", title: "Docs"},
      %{id: 2, page_id: nil, parent_id: 1, slug: "guides", title: "Guides"}
    ]

    assert {:ok, %{id: 3, parent_id: 2, slug: "install", title: "Install", page_id: nil}, nodes} =
             CreateNodeAtPath.call(nodes, ["docs", "guides", "install"], %{
               title: "Install"
             })

    assert [
             %{id: 1, parent_id: nil, slug: "docs", title: "Docs", page_id: nil},
             %{id: 2, parent_id: 1, slug: "guides", title: "Guides", page_id: nil},
             %{id: 3, parent_id: 2, slug: "install", title: "Install", page_id: nil}
           ] = nodes
  end

  test "CreateNodeAtPath.call returns the existing leaf without changing it" do
    nodes = [
      %{id: 1, page_id: nil, parent_id: nil, slug: "docs", title: "Docs"},
      %{id: 2, page_id: "page-1", parent_id: 1, slug: "install", title: "Install"}
    ]

    assert {:ok, %{id: 2, page_id: "page-1", parent_id: 1, slug: "install", title: "Install"},
            ^nodes} =
             CreateNodeAtPath.call(nodes, "docs/install", %{
               title: "Ignored",
               page_id: "page-2"
             })
  end

  test "CreateNodeAtPath.call rejects invalid attrs and invalid paths" do
    nodes = []

    assert {:error, :invalid_attrs} == CreateNodeAtPath.call(nodes, "docs", %{})

    assert {:error, :invalid_attrs} ==
             CreateNodeAtPath.call(nodes, "docs", %{title: "Docs", extra: true})

    assert {:error, :invalid_path} == CreateNodeAtPath.call(nodes, "", %{title: "Docs"})

    assert {:error, :invalid_path} ==
             CreateNodeAtPath.call(nodes, ["docs", ""], %{title: "Docs"})
  end
end
