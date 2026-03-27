# TODO: move to TreeOps

defmodule Qblog.Wiki.PageTree.TreeQueries.ByPath.Create do
  def call(nodes, path, attrs \\ %{})

  def call(nodes, path, attrs) when is_binary(path) do
    nodes
    |> call(String.split(path, "/", trim: true), attrs)
  end

  def call(nodes, path, attrs) when is_list(path) and is_map(attrs) do
    with :ok <- validate_path(path),
         {:ok, leaf_attrs} <- validate_leaf_attrs(attrs) do
      {leaf_node, _parent_id, nodes} =
        Enum.reduce(Enum.with_index(path), {nil, nil, nodes}, fn {slug, index},
                                                                 {_leaf_node, parent_id,
                                                                  nodes_acc} ->
          leaf? = index == length(path) - 1

          case find_node_by_slug_and_parent_id(nodes_acc, slug, parent_id) do
            nil ->
              node =
                new_node(
                  nodes_acc,
                  slug,
                  node_title(slug, leaf?, leaf_attrs),
                  parent_id,
                  node_page_id(leaf?, leaf_attrs)
                )

              {node, node.id, nodes_acc ++ [node]}

            node ->
              {node, node.id, nodes_acc}
          end
        end)

      {:ok, leaf_node, nodes}
    end
  end

  defp validate_path([]), do: {:error, :invalid_path}

  defp validate_path(path) when is_list(path),
    do: if(Enum.all?(path, &(&1 != "")), do: :ok, else: {:error, :invalid_path})

  defp validate_leaf_attrs(attrs) do
    allowed_keys = MapSet.new([:page_id, :title])

    cond do
      not Map.has_key?(attrs, :title) ->
        {:error, :invalid_attrs}

      not Enum.all?(Map.keys(attrs), &MapSet.member?(allowed_keys, &1)) ->
        {:error, :invalid_attrs}

      true ->
        {:ok, attrs}
    end
  end

  defp find_node_by_slug_and_parent_id(nodes, slug, parent_id) do
    Enum.find(nodes, &(&1.slug == slug and &1.parent_id == parent_id))
  end

  defp node_title(slug, false, _leaf_attrs), do: slug_to_title(slug)
  defp node_title(_slug, true, leaf_attrs), do: leaf_attrs.title

  defp node_page_id(false, _leaf_attrs), do: nil
  defp node_page_id(true, leaf_attrs), do: Map.get(leaf_attrs, :page_id)

  defp new_node(nodes, slug, title, parent_id, page_id) do
    %{
      id: next_id(nodes),
      page_id: page_id,
      parent_id: parent_id,
      slug: slug,
      title: title
    }
  end

  defp next_id([]), do: 1

  defp next_id(nodes) do
    nodes
    |> Enum.map(& &1.id)
    |> Enum.max()
    |> Kernel.+(1)
  end

  defp slug_to_title(slug) do
    slug
    |> String.split("-")
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
