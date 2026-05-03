defmodule Wik.Blocks.Types.ChildPages do
  @behaviour Wik.Blocks.Types.Behaviour

  def label, do: "Child pages"
  def type, do: :child_pages
  def supports_history?, do: false
  def supports_title?, do: true
  def default_data, do: %{"source" => "current_page", "title" => ""}
  def create_initial_version(_block, _opts), do: :ok

  def block_to_form_params(%{data: %{"title" => title} = block_data}, _params, _page_tree) do
    source = block_data["source"]
    node_id = block_data["node_id"]
    source_page = source_page_value(source, node_id)

    # TODO: rename source_page to source_node?
    # TODO: add support for root node + max depth
    %{
      "node_id" => source_page_value(source, node_id) || "",
      "source" => source,
      "source_page" => source_page,
      "title" => title
    }
  end

  def update_block(block, params, opts) do
    _scope = Keyword.fetch!(opts, :scope)

    block
    |> Ash.update(
      %{data: params |> params_to_data()},
      opts |> Keyword.put(:action, :update)
    )
  end

  def version_to_text(_block, _version, _opts), do: {:error, :unsupported}

  # TODO: simplify?
  def validate_data(data) do
    with :ok <- validate_title(data) do
      case {data["source"], data["node_id"]} do
        {nil, nil} ->
          :ok

        {"current_page", nil} ->
          :ok

        {"node", node_id} when is_integer(node_id) ->
          :ok

        {"current_page", node_id} when node_id in ["", nil] ->
          :ok

        _ ->
          {:error, field: :data, message: "child pages blocks need a valid source"}
      end
    end
  end

  # TODO: simplify?
  defp params_to_data(params) do
    params
    |> source_params_to_data()
    |> Map.put("title", params["title"])
  end

  defp source_params_to_data(%{"source_page" => "current_page"}) do
    %{"source" => "current_page"}
  end

  defp source_params_to_data(%{"source_page" => node_id})
       when is_binary(node_id) and node_id != "" do
    with {node_id, ""} <- Integer.parse(node_id) do
      %{"node_id" => node_id, "source" => "node"}
    else
      _ -> %{"source" => "current_page"}
    end
  end

  defp source_params_to_data(%{"source" => "node", "node_id" => node_id})
       when is_integer(node_id) do
    %{"node_id" => node_id, "source" => "node"}
  end

  defp source_params_to_data(_params) do
    %{"source" => "current_page"}
  end

  defp source_page_value("node", node_id) when node_id not in [nil, ""], do: to_string(node_id)
  defp source_page_value("current_page", _node_id), do: "current_page"
  defp source_page_value(_source, _node_id), do: nil

  defp validate_title(%{"title" => title}) when is_binary(title), do: :ok

  defp validate_title(_data) do
    {:error, field: :data, message: "block title must be a string"}
  end
end
