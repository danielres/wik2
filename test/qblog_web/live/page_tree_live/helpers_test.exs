defmodule QblogWeb.PageTreeLive.HelpersTest do
  use ExUnit.Case, async: true

  alias QblogWeb.PageTreeLive.Helpers

  test "get_node_by_id returns a placeholder top node for nil" do
    assert %{id: nil, slug: "top", title: "Top"} = Helpers.get_node_by_id([], nil)
  end

  test "parent_options rejects the current node, its parent, descendants, and parents with a matching child slug" do
    nodes = [
      %{id: 1, parent_id: nil, slug: "home", title: "Home"},
      %{id: 2, parent_id: 1, slug: "about", title: "About"},
      %{id: 3, parent_id: nil, slug: "docs", title: "Docs"},
      %{id: 4, parent_id: 3, slug: "about", title: "About"},
      %{id: 5, parent_id: nil, slug: "blog", title: "Blog"},
      %{id: 6, parent_id: 2, slug: "faq", title: "Faq"}
    ]

    assert [4, 5] == node_ids(Helpers.parent_options(nodes, 2))
  end

  test "parent_options keeps parents whose direct children use a different slug" do
    nodes = [
      %{id: 1, parent_id: nil, slug: "home", title: "Home"},
      %{id: 2, parent_id: 1, slug: "about", title: "About"},
      %{id: 3, parent_id: nil, slug: "docs", title: "Docs"},
      %{id: 4, parent_id: 3, slug: "faq", title: "Faq"},
      %{id: 5, parent_id: nil, slug: "blog", title: "Blog"}
    ]

    assert [3, 4, 5] == node_ids(Helpers.parent_options(nodes, 2))
  end

  defp node_ids(nodes), do: Enum.map(nodes, & &1.id)
end
