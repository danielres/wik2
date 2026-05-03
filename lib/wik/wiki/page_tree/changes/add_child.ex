defmodule Wik.Wiki.PageTree.Changes.AddChild do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    # TODO: just pass props map instead
    nodes = Ash.Changeset.get_attribute(changeset, :nodes)
    parent_id = Ash.Changeset.get_argument(changeset, :parent_id)
    slug = Ash.Changeset.get_argument(changeset, :slug)
    title = Ash.Changeset.get_argument(changeset, :title)

    case Wik.Wiki.PageTree.TreeOps.AddChild.call(nodes, slug, title, parent_id) do
      {:ok, new_nodes} ->
        Ash.Changeset.change_attribute(changeset, :nodes, new_nodes)

      {:error, message} ->
        Ash.Changeset.add_error(changeset, field: :nodes, message: message)
    end
  end
end
