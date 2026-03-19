defmodule Qblog.Wiki.PageTree.Changes.RemoveNode do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    nodes = Ash.Changeset.get_attribute(changeset, :nodes)
    node_id = Ash.Changeset.get_argument(changeset, :node_id)

    case Qblog.Wiki.PageTree.TreeOps.RemoveNode.call(nodes, node_id) do
      {:ok, new_nodes} ->
        Ash.Changeset.change_attribute(changeset, :nodes, new_nodes)

      {:error, message} ->
        Ash.Changeset.add_error(changeset, field: :nodes, message: message)
    end
  end
end
