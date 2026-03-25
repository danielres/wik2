defmodule Qblog.Wiki.PageTree.Changes.ValidateUniqueSiblingSlugs do
  use Ash.Resource.Change

  alias Qblog.Wiki.PageTree.TreeQueries
  alias Qblog.Wiki.PageTree.TreeOps.ValidateUniqueSiblingSlugs

  @impl true
  def change(changeset, _opts, _context) do
    nodes = Ash.Changeset.get_attribute(changeset, :nodes) || []

    case ValidateUniqueSiblingSlugs.call(nodes) do
      :ok ->
        changeset

      {:error, :duplicate_sibling_slug, %{parent_id: parent_id, slug: slug}} ->
        Ash.Changeset.add_error(
          changeset,
          field: :nodes,
          message: duplicate_sibling_slug_message(nodes, parent_id, slug)
        )
    end
  end

  defp duplicate_sibling_slug_message(_nodes, nil, slug),
    do: ~s("/#{slug}" already exists at top level)

  defp duplicate_sibling_slug_message(nodes, parent_id, slug) do
    parent = TreeQueries.get_node(nodes, parent_id)
    ~s("#{parent.slug}/#{slug}" already exists)
  end
end
