defmodule Qblog.Blocks.Types.Markdown do
  @behaviour Qblog.Blocks.Types.Behaviour

  alias Qblog.Wiki.PageTree.Wikilinks

  def label, do: "Markdown"
  def type, do: :markdown
  def supports_title?, do: false
  def default_data, do: %{"text" => ""}

  def block_to_form_params(block, %{}, page_tree) do
    %{"text" => text} = block.data

    wikilink_map = page_tree.nodes |> Wikilinks.title_paths_to_node_id_map() |> Jason.encode!()

    %{
      "text" => Wikilinks.nodes_to_title_paths(text, page_tree),
      "wikilink_map" => wikilink_map
    }
  end

  def block_to_form_params(
        _block,
        %{"text" => _text, "wikilink_map" => _wikilink_map} = params,
        _page_tree
      ) do
    params
  end

  def canonical_text_from_params(params) do
    text =
      case params do
        %{"text" => text} when is_binary(text) -> text
        _ -> nil
      end

    text |> canonicalize_text(params["wikilink_map"])
  end

  def update_block(block, params, opts) do
    block
    |> Ash.update(
      %{
        data: %{
          "text" => params |> canonical_text_from_params()
        }
      },
      opts |> Keyword.put(:action, :update)
    )
  end

  def validate_data(data) do
    case data do
      %{"text" => text} when is_binary(text) ->
        :ok

      %{"text" => _text} ->
        {:error, field: :data, message: "markdown blocks must store text as a string"}

      _data ->
        {:error, field: :data, message: "markdown blocks must store text"}
    end
  end

  defp canonicalize_text(text, wikilink_map_json) when is_binary(text) do
    {:ok, %{} = wikilink_map} = Jason.decode(wikilink_map_json)

    text
    |> String.replace(~r/\r\n?/, "\n")
    |> String.split("\n")
    |> Enum.map(&String.trim_trailing/1)
    |> Enum.join("\n")
    |> String.trim()
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> Wikilinks.title_paths_to_nodes(wikilink_map)
  end

  defp canonicalize_text(_text, _wikilink_map_json), do: ""
end
