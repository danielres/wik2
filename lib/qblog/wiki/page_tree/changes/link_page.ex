defmodule Qblog.Wiki.PageTree.Changes.LinkPage do
  use Ash.Resource.Change

  alias Qblog.Wiki.PageTree.TreeQueries

  @impl true
  def change(changeset, _opts, _context) do
    nodes = Ash.Changeset.get_attribute(changeset, :nodes)
    node_id = Ash.Changeset.get_argument(changeset, :node_id)
    page_id = Ash.Changeset.get_argument(changeset, :page_id)

    case TreeQueries.get_node(nodes, node_id) do
      nil ->
        Ash.Changeset.add_error(changeset, field: :nodes, message: "node not found")

      %{page_id: existing_page_id} when not is_nil(existing_page_id) ->
        Ash.Changeset.add_error(changeset, field: :nodes, message: "node already has a page")

      _node ->
        new_nodes =
          Enum.map(nodes, fn
            %{id: ^node_id} = node -> %{node | page_id: page_id}
            node -> node
          end)

        Ash.Changeset.change_attribute(changeset, :nodes, new_nodes)
    end
  end
end
