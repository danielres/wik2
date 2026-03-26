defmodule QblogWeb.PageTreeLive.PageTreeEditor.MoveNodeFlow do
  alias Qblog.Wiki.PageTree

  defstruct open?: false, node_id: nil

  def init, do: %__MODULE__{}

  def open(node_id) do
    node_id = node_id |> parse_optional_node_id()
    %__MODULE__{open?: true, node_id: node_id}
  end

  def submit(flow, page_tree, new_parent_id, scope) do
    case PageTree.move_node(page_tree, flow.node_id, new_parent_id, scope: scope) do
      {:ok, page_tree} ->
        {:ok, init(), page_tree}

      {:error, err} ->
        {:error, flow, err}
    end
  end

  defp parse_optional_node_id(""), do: nil
  defp parse_optional_node_id(value), do: value |> String.to_integer()
end
