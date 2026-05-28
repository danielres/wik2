defmodule Wik.Blocks.Types.Embed do
  def create_initial_version(_block, _opts), do: :ok

  def default_data, do: %{"title" => "", "url" => ""}

  def block_to_form_params(%{data: %{"title" => title, "url" => url}}, _params, _page_tree) do
    %{"title" => title, "url" => url}
  end

  def update_block(block, params, opts, normalize_embed_input)
      when is_function(normalize_embed_input, 1) do
    _scope = Keyword.fetch!(opts, :scope)

    with {:ok, url} <- normalize_embed_input.(params["url"]) do
      block
      |> Ash.update(
        %{data: %{"title" => params["title"], "url" => url}},
        opts |> Keyword.put(:action, :update)
      )
    end
  end

  def version_to_text(_block, _version, _opts), do: {:error, :unsupported}

  def validate_title(%{"title" => title}) when is_binary(title), do: :ok

  def validate_title(_data) do
    {:error, field: :data, message: "block title must be a string"}
  end
end
