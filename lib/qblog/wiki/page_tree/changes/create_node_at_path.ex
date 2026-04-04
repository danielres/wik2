defmodule Qblog.Wiki.PageTree.Changes.CreateNodeAtPath do
  use Ash.Resource.Change

  alias Qblog.Wiki.PageTree.TreeOps
  alias Qblog.Wiki.PageTree.TreeQueries

  @impl true
  def change(changeset, _opts, _context) do
    nodes = Ash.Changeset.get_attribute(changeset, :nodes)
    path = Ash.Changeset.get_argument(changeset, :path)
    page_id = Ash.Changeset.get_argument(changeset, :page_id)
    title = Ash.Changeset.get_argument(changeset, :title)

    case TreeQueries.get_node_by_path(nodes, path) do
      {:ok, _node} ->
        Ash.Changeset.add_error(changeset, field: :nodes, message: "path already exists")

      {:error, :not_found} ->
        case TreeOps.create_node_at_path(nodes, path, %{page_id: page_id, title: title}) do
          {:ok, _leaf_node, new_nodes} ->
            Ash.Changeset.change_attribute(changeset, :nodes, new_nodes)

          {:error, _reason} ->
            Ash.Changeset.add_error(changeset, field: :nodes, message: "could not create path")
        end
    end
  end
end
