defmodule Qblog.Blocks.Types.Pages do
  @behaviour Qblog.Blocks.Types.Behaviour

  def label, do: "Pages"
  def type, do: :pages
  def supports_title?, do: true
  def default_data, do: %{"depth" => 1, "source_node" => "root", "title" => ""}

  def block_to_form_params(
        %{data: %{"depth" => depth, "source_node" => source_node, "title" => title}},
        _params,
        _page_tree
      ) do
    %{
      "depth" => depth,
      "source_node" => source_node_to_form_value(source_node),
      "title" => title
    }
  end

  def update_block(block, params, opts) do
    _scope = Keyword.fetch!(opts, :scope)

    block
    |> Ash.update(
      %{data: params_to_data(params)},
      opts |> Keyword.put(:action, :update)
    )
  end

  def validate_data(%{"depth" => depth, "source_node" => source_node, "title" => title})
      when is_integer(depth) and depth >= 1 and is_binary(title) do
    validate_source_node(source_node)
  end

  def validate_data(_data) do
    {:error, field: :data, message: "pages blocks need a valid source node, depth, and title"}
  end

  defp params_to_data(%{"depth" => depth, "source_node" => source_node, "title" => title}) do
    %{
      "depth" => parse_depth(depth),
      "source_node" => parse_source_node(source_node),
      "title" => title
    }
  end

  defp parse_depth(depth) when is_integer(depth) and depth >= 1, do: depth

  defp parse_depth(depth) when is_binary(depth) do
    {depth, ""} = Integer.parse(depth)
    depth
  end

  defp parse_source_node("root"), do: "root"
  defp parse_source_node(node_id) when is_integer(node_id), do: node_id

  defp parse_source_node(node_id) when is_binary(node_id) do
    {node_id, ""} = Integer.parse(node_id)
    node_id
  end

  defp source_node_to_form_value("root"), do: "root"
  defp source_node_to_form_value(node_id) when is_integer(node_id), do: to_string(node_id)

  defp validate_source_node("root"), do: :ok
  defp validate_source_node(source_node) when is_integer(source_node), do: :ok

  defp validate_source_node(_source_node) do
    {:error, field: :data, message: "pages blocks need a valid source node"}
  end
end
