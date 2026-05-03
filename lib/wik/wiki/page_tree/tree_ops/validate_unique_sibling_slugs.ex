defmodule Wik.Wiki.PageTree.TreeOps.ValidateUniqueSiblingSlugs do
  def call(nodes) when is_list(nodes) do
    case find_duplicate_sibling_slug(nodes) do
      nil ->
        :ok

      {parent_id, slug} ->
        {
          :error,
          :duplicate_sibling_slug,
          %{parent_id: parent_id, slug: slug}
        }
    end
  end

  defp find_duplicate_sibling_slug(nodes) do
    Enum.find_value(nodes, fn node ->
      duplicate? =
        Enum.any?(nodes, fn other ->
          other.id != node.id and
            other.slug == node.slug and
            other.parent_id == node.parent_id
        end)

      if duplicate?, do: {node.parent_id, node.slug}
    end)
  end
end
