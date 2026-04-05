defmodule Qblog.Wiki.PageTree.Changes.DestroyNode do
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Qblog.Wiki.Page
  alias Qblog.Wiki.PageTree.TreeOps
  alias Qblog.Wiki.PageTree.TreeQueries

  @impl true
  def change(changeset, _opts, context) do
    nodes = Changeset.get_attribute(changeset, :nodes)
    node_id = Changeset.get_argument(changeset, :node_id)
    destroy_page? = Changeset.get_argument(changeset, :destroy_page?)
    page_id = nodes |> TreeQueries.get_node(node_id) |> then(&(&1 && &1.page_id))

    case TreeOps.DestroyNode.call(nodes, node_id) do
      {:ok, new_nodes} ->
        changeset
        |> Changeset.change_attribute(:nodes, new_nodes)
        |> maybe_destroy_page?(destroy_page?, page_id, context)

      {:error, message} ->
        Changeset.add_error(changeset, field: :nodes, message: message)
    end
  end

  defp maybe_destroy_page?(changeset, false, _page_id, _context), do: changeset
  defp maybe_destroy_page?(changeset, true, nil, _context), do: changeset

  defp maybe_destroy_page?(changeset, true, page_id, context) do
    Changeset.after_action(changeset, fn _changeset, page_tree ->
      case Ash.get(Page, page_id, authorize?: false, domain: Qblog.Wiki, scope: context) do
        {:ok, nil} ->
          {:ok, page_tree}

        {:ok, page} ->
          case Ash.destroy(page, authorize?: false, scope: context) do
            :ok -> {:ok, page_tree}
            {:ok, _page} -> {:ok, page_tree}
            {:error, error} -> {:error, error}
          end

        {:error, error} ->
          {:error, error}
      end
    end)
  end
end
