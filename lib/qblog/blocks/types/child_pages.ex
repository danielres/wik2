defmodule Qblog.Blocks.Types.ChildPages do
  @behaviour Qblog.Blocks.Types.Behaviour

  def label, do: "Child pages"
  def type, do: :child_pages
  def default_data, do: %{"source" => "current_page"}

  def block_to_form_params(block, params, _page_tree) do
    source = params["source"] || block.data["source"]
    node_id = params["node_id"] || block.data["node_id"]

    %{
      "node_id" => source_page_value(source, node_id) || "",
      "source" => source || "current_page",
      "source_page" => params["source_page"] || source_page_value(source, node_id)
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

  def validate_data(data) do
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

  defp params_to_data(%{"source_page" => "current_page"}) do
    %{"source" => "current_page"}
  end

  defp params_to_data(%{"source_page" => node_id}) when is_binary(node_id) and node_id != "" do
    with {node_id, ""} <- Integer.parse(node_id) do
      %{"node_id" => node_id, "source" => "node"}
    else
      _ -> %{"source" => "current_page"}
    end
  end

  defp params_to_data(%{"source" => "node", "node_id" => node_id}) when is_integer(node_id) do
    %{"node_id" => node_id, "source" => "node"}
  end

  defp params_to_data(_params) do
    %{"source" => "current_page"}
  end

  defp source_page_value("node", node_id) when node_id not in [nil, ""], do: to_string(node_id)
  defp source_page_value("current_page", _node_id), do: "current_page"
  defp source_page_value(_source, _node_id), do: nil
end
