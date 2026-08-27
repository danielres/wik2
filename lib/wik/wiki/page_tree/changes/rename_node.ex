defmodule Wik.Wiki.PageTree.Changes.RenameNode do
  use Ash.Resource.Change

  alias Wik.Wiki.PageTree.TreeOps.RenameNode

  @impl true
  def change(changeset, _opts, _context) do
    nodes = Ash.Changeset.get_attribute(changeset, :nodes)
    node_id = Ash.Changeset.get_argument(changeset, :node_id)
    slug = Ash.Changeset.get_argument(changeset, :slug)
    title = Ash.Changeset.get_argument(changeset, :title)

    case RenameNode.call(nodes, node_id, slug, title) do
      {:ok, renamed_nodes} ->
        Ash.Changeset.change_attribute(changeset, :nodes, renamed_nodes)

      {:error, message} ->
        Ash.Changeset.add_error(changeset, field: :nodes, message: message)
    end
  end
end
