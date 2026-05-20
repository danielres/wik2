defmodule Wik.Blocks.Types.Markdown do
  @behaviour Wik.Blocks.Types.Behaviour

  alias Wik.Accounts
  alias Wik.Blocks.Versioning
  alias Wik.Wiki.PageTree.Wikilinks

  def label, do: "Markdown"
  def type, do: :markdown
  def supports_history?, do: true
  def supports_title?, do: false
  def default_data, do: %{"text" => ""}

  def create_initial_version(block, opts) do
    block
    |> block_to_canonical_text()
    |> then(&Versioning.create_initial_text_version(block, &1, opts))
  end

  def block_to_form_params(block, %{}, page_tree) do
    %{"text" => text} = block.data

    wikilink_map = page_tree.nodes |> Wikilinks.title_paths_to_node_id_map() |> Jason.encode!()
    wikilink_member_map = page_tree |> wikilink_member_map() |> Jason.encode!()

    %{
      "text" =>
        text
        |> Wikilinks.nodes_to_title_paths(page_tree)
        |> Wikilinks.memberships_to_usernames(member_id_to_username_map(page_tree)),
      "wikilink_map" => wikilink_map,
      "wikilink_member_map" => wikilink_member_map
    }
  end

  def block_to_form_params(_block, %{"text" => _text} = params, page_tree) do
    params
    |> Map.put_new(
      "wikilink_map",
      page_tree.nodes |> Wikilinks.title_paths_to_node_id_map() |> Jason.encode!()
    )
    |> Map.put_new("wikilink_member_map", page_tree |> wikilink_member_map() |> Jason.encode!())
  end

  def update_block(block, params, opts) do
    current_text = block |> block_to_canonical_text()
    updated_text = params |> params_to_canonical_text()

    if updated_text == current_text do
      {:ok, block}
    else
      updated_data = block.data |> Map.put("text", updated_text)

      Versioning.update_block_with_text_version(
        block,
        current_text,
        updated_text,
        updated_data,
        opts
      )
    end
  end

  def version_to_text(block, version, opts), do: Versioning.version_to_text(block, version, opts)

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

  defp block_to_canonical_text(block), do: block.data["text"] || ""

  defp params_to_canonical_text(params) do
    text =
      case params do
        %{"text" => text} when is_binary(text) -> text
        _ -> nil
      end

    text |> canonicalize_text(params["wikilink_map"], params["wikilink_member_map"])
  end

  defp canonicalize_text(text, wikilink_map_json, wikilink_member_map_json)
       when is_binary(text) do
    {:ok, %{} = wikilink_map} = Jason.decode(wikilink_map_json || "{}")
    {:ok, %{} = wikilink_member_map} = Jason.decode(wikilink_member_map_json || "{}")

    text
    |> String.replace(~r/\r\n?/, "\n")
    |> String.split("\n")
    |> Enum.map(&String.trim_trailing/1)
    |> Enum.join("\n")
    |> String.trim()
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> Wikilinks.title_paths_to_nodes(wikilink_map)
    |> Wikilinks.usernames_to_memberships(wikilink_member_map)
  end

  defp canonicalize_text(_text, _wikilink_map_json, _wikilink_member_map_json), do: ""

  defp member_id_to_username_map(%{group_id: group_id}) when is_binary(group_id),
    do: Accounts.membership_id_to_username_map(group_id)

  defp member_id_to_username_map(_page_tree), do: %{}

  defp wikilink_member_map(%{group_id: group_id}) when is_binary(group_id),
    do: Accounts.username_to_membership_id_map(group_id)

  defp wikilink_member_map(_page_tree), do: %{}
end
